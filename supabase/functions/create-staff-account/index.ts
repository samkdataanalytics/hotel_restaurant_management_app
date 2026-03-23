import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

interface PropertyAssignment {
  propertyId: string
  permissions: Record<string, string> // sectionKey → privilege ('none'|'view'|'edit')
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body = await req.json()
    const {
      username,
      password,
      primaryPropertyId,
      orgId,
      role = 'staff',
      propertyAssignments = [],
    }: {
      username: string
      password: string
      primaryPropertyId: string
      orgId: string
      role?: string
      propertyAssignments?: PropertyAssignment[]
    } = body

    if (!username || !password || !primaryPropertyId || !orgId) {
      return json({ error: 'Missing required fields: username, password, primaryPropertyId, orgId' }, 400)
    }
    if (password.length < 6) {
      return json({ error: 'Password must be at least 6 characters' }, 400)
    }
    const validRoles = ['staff', 'manager']
    if (!validRoles.includes(role)) {
      return json({ error: `Invalid role "${role}". Must be one of: ${validRoles.join(', ')}` }, 400)
    }

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return json({ error: 'Not authenticated' }, 401)

    const supabaseUrl    = Deno.env.get('SUPABASE_URL')!
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const anonKey        = Deno.env.get('SUPABASE_ANON_KEY')!

    // Admin client — service role for auth.admin operations + SECURITY DEFINER RPCs
    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    // User client — verifies caller's identity and authorization
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth:   { autoRefreshToken: false, persistSession: false },
    })

    const { data: { user: caller }, error: callerErr } = await userClient.auth.getUser()
    if (!caller || callerErr) return json({ error: 'Not authenticated' }, 401)

    // Verify caller is a manager/owner for the primary property
    const { data: staffRow } = await userClient.from('property_staff').select('role')
      .eq('property_id', primaryPropertyId).eq('user_id', caller.id).maybeSingle()
    const { data: hotelRow } = await userClient.from('hotel_users').select('role')
      .eq('hotel_id', primaryPropertyId).eq('user_id', caller.id).maybeSingle()

    const isManager =
      (staffRow && staffRow.role === 'manager') ||
      (hotelRow && ['owner', 'manager'].includes(hotelRow.role))

    if (!isManager) {
      return json({ error: 'Not authorized. Only property managers can create staff accounts.' }, 403)
    }

    // ── Step 1: Pre-compute globally unique username ───────────────────────────
    const { data: finalUsername, error: resolveErr } = await adminClient.rpc(
      'resolve_staff_username',
      { p_username: username },
    )
    if (resolveErr || !finalUsername) {
      return json({ error: `Could not resolve username: ${resolveErr?.message ?? 'unknown error'}` }, 500)
    }

    const syntheticEmail = `${finalUsername}@staff.internal`

    // ── Step 2: Create the Supabase auth user ─────────────────────────────────
    const { data: newUser, error: createError } = await adminClient.auth.admin.createUser({
      email:         syntheticEmail,
      password,
      email_confirm: true,
      user_metadata: { full_name: finalUsername },
    })
    if (createError || !newUser?.user) {
      return json({ error: createError?.message ?? 'Failed to create account' }, 400)
    }

    const userId = newUser.user.id

    // ── Step 3: Primary property setup via create_staff_member ────────────────
    // Find the primary assignment's permissions (empty = full access for manager)
    const primaryAssignment = (propertyAssignments as PropertyAssignment[])
      .find((a) => a.propertyId === primaryPropertyId)
    const primaryPerms = primaryAssignment?.permissions ?? {}

    const { data: confirmedUsername, error: setupErr } = await adminClient.rpc(
      'create_staff_member',
      {
        p_user_id:     userId,
        p_username:    username,
        p_email:       syntheticEmail,
        p_property_id: primaryPropertyId,
        p_org_id:      orgId,
        p_permissions: primaryPerms,
        p_role:        role,
      },
    )

    if (setupErr) {
      await adminClient.auth.admin.deleteUser(userId)
      console.error('create_staff_member rpc error:', setupErr.message)
      return json({ error: `Failed to set up staff member: ${setupErr.message}` }, 500)
    }

    // ── Step 4: Assign to additional properties ────────────────────────────────
    const additionalAssignments = (propertyAssignments as PropertyAssignment[])
      .filter((a) => a.propertyId !== primaryPropertyId)

    for (const assignment of additionalAssignments) {
      const { error: addErr } = await adminClient.rpc('add_staff_to_property', {
        p_user_id:     userId,
        p_property_id: assignment.propertyId,
        p_role:        role,
        p_permissions: assignment.permissions ?? {},
      })
      if (addErr) {
        console.error(`add_staff_to_property failed for ${assignment.propertyId}:`, addErr.message)
      }
    }

    return json({ userId, username: confirmedUsername ?? finalUsername }, 200)
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err)
    return json({ error: `Unexpected error: ${msg}` }, 500)
  }
})

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
