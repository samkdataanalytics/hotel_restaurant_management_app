import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body = await req.json()
    const { username, password, propertyId, orgId, permissions } = body

    if (!username || !password || !propertyId || !orgId) {
      return json({ error: 'Missing required fields: username, password, propertyId, orgId' }, 400)
    }
    if (password.length < 6) {
      return json({ error: 'Password must be at least 6 characters' }, 400)
    }

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return json({ error: 'Not authenticated' }, 401)

    const supabaseUrl    = Deno.env.get('SUPABASE_URL')!
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const anonKey        = Deno.env.get('SUPABASE_ANON_KEY')!

    // Admin client — only used for auth.admin.createUser (service role required)
    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    // User client — verifies the caller's identity and authorization
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth:   { autoRefreshToken: false, persistSession: false },
    })

    const { data: { user: caller }, error: callerErr } = await userClient.auth.getUser()
    if (!caller || callerErr) return json({ error: 'Not authenticated' }, 401)

    // Verify caller is a manager/owner for this property
    const { data: staffRow } = await userClient.from('property_staff').select('role')
      .eq('property_id', propertyId).eq('user_id', caller.id).maybeSingle()
    const { data: hotelRow } = await userClient.from('hotel_users').select('role')
      .eq('hotel_id', propertyId).eq('user_id', caller.id).maybeSingle()

    const isManager =
      (staffRow && staffRow.role === 'manager') ||
      (hotelRow && ['owner', 'manager'].includes(hotelRow.role))

    if (!isManager) {
      return json({ error: 'Not authorized. Only property managers can create staff accounts.' }, 403)
    }

    const cleanUsername  = username.toLowerCase().trim().replace(/\s+/g, '_')
    const syntheticEmail = `${cleanUsername}@staff.internal`

    // ── Step 1: Create the Supabase auth user ─────────────────────────────────
    const { data: newUser, error: createError } = await adminClient.auth.admin.createUser({
      email: syntheticEmail,
      password,
      email_confirm: true,
      user_metadata: { full_name: username },
    })

    if (createError || !newUser?.user) {
      const msg      = createError?.message ?? 'Failed to create account'
      const friendly = (msg.includes('already been registered') || msg.includes('duplicate'))
        ? `The username "${cleanUsername}" is already taken. Please choose a different one.`
        : msg
      return json({ error: friendly }, 400)
    }

    const userId = newUser.user.id

    // ── Step 2: Set up profile + org + property via SECURITY DEFINER function ─
    // This runs with owner (postgres) privileges so no table-grant issues.
    const { error: setupErr } = await adminClient.rpc('create_staff_member', {
      p_user_id:     userId,
      p_username:    cleanUsername,
      p_email:       syntheticEmail,
      p_property_id: propertyId,
      p_org_id:      orgId,
      p_permissions: permissions ?? {},
    })

    if (setupErr) {
      // Roll back: remove the auth user so they don't end up in a broken state
      await adminClient.auth.admin.deleteUser(userId)
      console.error('create_staff_member rpc error:', setupErr.message)
      return json({ error: `Failed to set up staff member: ${setupErr.message}` }, 500)
    }

    return json({ userId, username: cleanUsername }, 200)
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
