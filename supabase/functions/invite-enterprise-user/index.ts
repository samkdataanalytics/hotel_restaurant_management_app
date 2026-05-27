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
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...cors, 'Content-Type': 'application/json' },
    })

  if (req.method === 'OPTIONS') return json('ok')

  try {
    const supabaseUrl    = Deno.env.get('SUPABASE_URL')!
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const anonKey        = Deno.env.get('SUPABASE_ANON_KEY')!
    const appUrl         = Deno.env.get('APP_URL') ?? 'https://yourdomain.com'

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return json({ error: 'Not authenticated' }, 401)

    // Verify the caller is a superadmin
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth:   { autoRefreshToken: false, persistSession: false },
    })

    const { data: { user }, error: authErr } = await userClient.auth.getUser()
    if (!user || authErr) return json({ error: 'Not authenticated' }, 401)

    // Check superadmin status
    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    const { data: profile } = await adminClient
      .from('profiles')
      .select('is_superadmin')
      .eq('id', user.id)
      .maybeSingle()

    if (!profile?.is_superadmin) {
      return json({ error: 'Forbidden' }, 403)
    }

    const body = await req.json()
    const {
      email,
      maxProperties,
      maxUsers,
      maxRooms,
      maxTables,
      priceMonthly,
      priceAnnually,
      billingCycle,
    } = body as {
      email:         string
      maxProperties: number
      maxUsers:      number
      maxRooms:      number
      maxTables:     number
      priceMonthly:  number | null
      priceAnnually: number | null
      billingCycle:  string
    }

    if (!email || !maxProperties || !maxUsers || !maxRooms || !maxTables) {
      return json({ error: 'Missing required fields' }, 400)
    }

    const normalizedEmail = email.trim().toLowerCase()

    // Save provision config — upsert so re-inviting updates the limits
    const { error: upsertErr } = await adminClient
      .from('pending_provisions')
      .upsert({
        email:          normalizedEmail,
        max_properties: maxProperties,
        max_users:      maxUsers,
        max_rooms:      maxRooms,
        max_tables:     maxTables,
        price_monthly:  priceMonthly  ?? null,
        price_annually: priceAnnually ?? null,
        billing_cycle:  billingCycle  ?? 'monthly',
        provisioned_by: user.id,
      }, { onConflict: 'email' })

    if (upsertErr) {
      console.error('pending_provisions upsert error:', upsertErr)
      return json({ error: 'Failed to save provision config' }, 500)
    }

    // Send the signup invitation email
    const { error: inviteErr } = await adminClient.auth.admin.inviteUserByEmail(
      normalizedEmail,
      { redirectTo: `${appUrl}/onboarding` },
    )

    if (inviteErr) {
      // If the user already exists Supabase returns a specific error — that
      // case shouldn't reach this function (the caller checks first), but
      // handle it gracefully.
      console.error('inviteUserByEmail error:', inviteErr)
      return json({ error: inviteErr.message }, 400)
    }

    console.log(`Invited ${normalizedEmail} with pending enterprise provision`)
    return json({ success: true })

  } catch (err) {
    console.error('invite-enterprise-user unexpected error:', err)
    return json({ error: 'Internal server error' }, 500)
  }
})
