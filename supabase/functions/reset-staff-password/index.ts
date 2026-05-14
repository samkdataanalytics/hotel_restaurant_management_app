import { createClient } from 'npm:@supabase/supabase-js@2'

function buildCors(req: Request): Record<string, string> {
  const origin    = req.headers.get('Origin') ?? ''
  const devSuffix = Deno.env.get('PAYHERE_DEV_ORIGIN_SUFFIX') ?? ''
  const allowed =
    origin === 'https://www.hotrest.app' ||
    origin === 'https://hotrest.app'     ||
    origin.startsWith('http://localhost')  ||
    (devSuffix && origin.endsWith(devSuffix))
  return {
    'Access-Control-Allow-Origin':  allowed ? origin : 'https://www.hotrest.app',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
  }
}

Deno.serve(async (req: Request) => {
  const cors = buildCors(req)
  const json = (body: unknown, status: number) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...cors, 'Content-Type': 'application/json' },
    })

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: cors })
  }

  try {
    const { userId, newPassword } = await req.json()

    if (!userId || !newPassword) {
      return json({ error: 'Missing userId or newPassword' }, 400)
    }
    if (newPassword.length < 8) {
      return json({ error: 'Password must be at least 8 characters' }, 400)
    }

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return json({ error: 'Not authenticated' }, 401)

    const supabaseUrl    = Deno.env.get('SUPABASE_URL')!
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const anonKey        = Deno.env.get('SUPABASE_ANON_KEY')!

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })
    const userClient  = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    })

    const { data: { user: caller } } = await userClient.auth.getUser()
    if (!caller) return json({ error: 'Not authenticated' }, 401)

    // Collect property IDs where caller is an owner or manager
    const { data: callerStaff } = await userClient
      .from('property_staff')
      .select('property_id, role')
      .eq('user_id', caller.id)

    const { data: callerHotels } = await userClient
      .from('hotel_users')
      .select('hotel_id, role')
      .eq('user_id', caller.id)

    const managerPropertyIds = new Set<string>([
      ...(callerStaff  ?? []).filter((r: any) => ['owner', 'manager'].includes(r.role)).map((r: any) => r.property_id),
      ...(callerHotels ?? []).filter((r: any) => ['owner', 'manager'].includes(r.role)).map((r: any) => r.hotel_id),
    ])

    if (managerPropertyIds.size === 0) {
      return json({ error: 'Not authorized. You are not a manager of any property.' }, 403)
    }

    // Verify target user is staff on at least one of the caller's properties
    const { data: targetStaff } = await adminClient
      .from('property_staff')
      .select('property_id')
      .eq('user_id', userId)

    const allowed = (targetStaff ?? []).some((r: any) => managerPropertyIds.has(r.property_id))
    if (!allowed) {
      return json({ error: 'Not authorized. This user is not a member of your properties.' }, 403)
    }

    // Reset password
    const { error: resetError } = await adminClient.auth.admin.updateUserById(userId, {
      password: newPassword,
    })

    if (resetError) {
      console.error('reset-staff-password: updateUserById error:', resetError.message)
      return json({ error: 'Failed to reset password' }, 400)
    }

    return json({ success: true }, 200)
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err)
    console.error('reset-staff-password error:', msg)
    return json({ error: 'Unexpected error' }, 500)
  }
})
