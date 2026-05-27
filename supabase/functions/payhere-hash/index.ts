import { createClient } from 'npm:@supabase/supabase-js@2'
import { createHash } from 'node:crypto'

// Plan rank — higher = more expensive. Used to reject downgrades.
const PLAN_RANK: Record<string, number> = {
  free:       0,
  starter:    1,
  pro:        2,
  enterprise: 3,
}

function md5Upper(s: string): string {
  return createHash('md5').update(s).digest('hex').toUpperCase()
}

function buildCors(req: Request): Record<string, string> {
  const origin      = req.headers.get('Origin') ?? ''
  const devSuffix   = Deno.env.get('PAYHERE_DEV_ORIGIN_SUFFIX')   ?? ''
  const ngrokSuffix = Deno.env.get('PAYHERE_NGROK_ORIGIN_SUFFIX') ?? ''
  const allowed =
    origin === 'https://www.hotrest.app' ||
    origin === 'https://hotrest.app'     ||
    origin.startsWith('http://localhost')  ||
    (devSuffix   && origin.endsWith(devSuffix))   ||
    (ngrokSuffix && origin.endsWith(ngrokSuffix))
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
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return json({ error: 'Not authenticated' }, 401)

    const supabaseUrl    = Deno.env.get('SUPABASE_URL')!
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const anonKey        = Deno.env.get('SUPABASE_ANON_KEY')!

    // Strict origin allowlist — each registered PayHere domain has its own secret.
    // Reject any origin not in this list to prevent credential misuse.
    const origin = req.headers.get('Origin') ?? ''

    type EnvConfig = {
      merchantIdKey:     string
      merchantSecretKey: string
      checkoutUrl:       string
    }

    const ALLOWED_ORIGINS: Record<string, EnvConfig> = {
      'http://localhost':        { merchantIdKey: 'PAYHERE_SANDBOX_MERCHANT_ID', merchantSecretKey: 'PAYHERE_SECRET_LOCALHOST', checkoutUrl: 'https://sandbox.payhere.lk/pay/checkout' },
      'https://www.hotrest.app': { merchantIdKey: 'PAYHERE_MERCHANT_ID',         merchantSecretKey: 'PAYHERE_MERCHANT_SECRET',  checkoutUrl: 'https://www.payhere.lk/pay/checkout'         },
      'https://hotrest.app':     { merchantIdKey: 'PAYHERE_MERCHANT_ID',         merchantSecretKey: 'PAYHERE_MERCHANT_SECRET',  checkoutUrl: 'https://www.payhere.lk/pay/checkout'         },
    }

    // Allow any origin whose host ends with the dev Vercel project slug
    const DEV_ORIGIN_SUFFIX = Deno.env.get('PAYHERE_DEV_ORIGIN_SUFFIX') ?? ''
    if (DEV_ORIGIN_SUFFIX && origin.endsWith(DEV_ORIGIN_SUFFIX)) {
      ALLOWED_ORIGINS[origin] = {
        merchantIdKey:     'PAYHERE_SANDBOX_MERCHANT_ID',
        merchantSecretKey: 'PAYHERE_SECRET_DEV',
        checkoutUrl:       'https://sandbox.payhere.lk/pay/checkout',
      }
    }

    // Allow ngrok tunnel URLs used for local PayHere testing
    // (PayHere rejects localhost URLs — ngrok gives localhost a public URL)
    const NGROK_ORIGIN_SUFFIX = Deno.env.get('PAYHERE_NGROK_ORIGIN_SUFFIX') ?? ''
    if (NGROK_ORIGIN_SUFFIX && origin.endsWith(NGROK_ORIGIN_SUFFIX)) {
      ALLOWED_ORIGINS[origin] = {
        merchantIdKey:     'PAYHERE_SANDBOX_MERCHANT_ID',
        merchantSecretKey: 'PAYHERE_SECRET_NGROK',
        checkoutUrl:       'https://sandbox.payhere.lk/pay/checkout',
      }
    }

    // Normalize localhost with any port (e.g. http://localhost:54575 → http://localhost)
    const lookupOrigin = origin.startsWith('http://localhost')
      ? 'http://localhost'
      : origin

    const config = ALLOWED_ORIGINS[lookupOrigin]
    if (!config) {
      console.error('payhere-hash: rejected request from unlisted origin:', origin)
      return json({ error: 'Origin not allowed' }, 403)
    }

    const merchantId     = Deno.env.get(config.merchantIdKey)!
    const merchantSecret = Deno.env.get(config.merchantSecretKey)!
    const checkoutUrl    = config.checkoutUrl

    if (!merchantId || !merchantSecret) {
      console.error('PayHere credentials not configured for origin:', origin)
      return json({ error: 'Payment gateway not configured' }, 503)
    }

    // Verify the caller's identity
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth:   { autoRefreshToken: false, persistSession: false },
    })

    const { data: { user }, error: authErr } = await userClient.auth.getUser()
    if (!user || authErr) return json({ error: 'Not authenticated' }, 401)

    const body = await req.json()
    const { orderId, currency, orgId, planSlug, billingCycle } = body as {
      orderId:      string
      currency:     string
      orgId:        string
      planSlug:     string
      billingCycle: string
    }

    if (!orderId || !currency || !orgId || !planSlug || !billingCycle) {
      return json({ error: 'Missing required fields' }, 400)
    }

    if (!['monthly', 'annually'].includes(billingCycle)) {
      return json({ error: 'Invalid billing cycle' }, 400)
    }

    // Reject attempts to pay for the free plan
    if (planSlug === 'free') {
      return json({ error: 'Cannot purchase the free plan' }, 400)
    }

    // Validate the plan slug exists and is active
    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    const { data: plan, error: planErr } = await adminClient
      .from('plans')
      .select('slug, is_active, price_monthly')
      .eq('slug', planSlug)
      .eq('is_active', true)
      .maybeSingle()

    if (planErr) {
      console.error('payhere-hash: plan lookup error:', planErr.message, planErr.code)
      return json({ error: 'Payment gateway error. Please try again.' }, 500)
    }

    if (!plan) {
      console.error('payhere-hash: no active plan found for slug:', planSlug)
      return json({ error: `Invalid or inactive plan: '${planSlug}'` }, 400)
    }

    // Compute amount server-side — never trust the client-supplied value.
    // This prevents a malicious org admin from paying LKR 1 for any plan.
    const priceMonthly = Number(plan.price_monthly)
    const amount = billingCycle === 'annually'
      ? (priceMonthly * 12).toFixed(2)
      : priceMonthly.toFixed(2)

    // Only org owners (or members explicitly granted billing access) can upgrade
    const { data: member } = await userClient
      .from('organization_members')
      .select('role, can_manage_billing')
      .eq('org_id', orgId)
      .eq('user_id', user.id)
      .maybeSingle()

    if (!member) return json({ error: 'Permission denied' }, 403)
    if (member.role !== 'owner' && !member.can_manage_billing) {
      return json({ error: 'Only org owners can upgrade the plan.' }, 403)
    }

    // Reject downgrades — user must contact support to downgrade
    const { data: org } = await adminClient
      .from('organizations')
      .select('plan')
      .eq('id', orgId)
      .maybeSingle()

    if (org) {
      const currentRank   = PLAN_RANK[org.plan]  ?? 0
      const requestedRank = PLAN_RANK[planSlug]  ?? 0
      // Block genuine downgrades but allow same-plan renewal (enterprise customers paying their custom invoice).
      if (requestedRank < currentRank) {
        return json({ error: 'Cannot downgrade to a lower plan. Contact support if you need to change your plan.' }, 400)
      }
    }

    // Check for a pending order with the same orderId (idempotency guard)
    const { data: existing } = await adminClient
      .from('payhere_orders')
      .select('id, status')
      .eq('id', orderId)
      .maybeSingle()

    if (existing) {
      // Only allow re-use if the previous attempt never left pending (unlikely with UUID IDs, but safe)
      if (existing.status !== 'pending') {
        return json({ error: 'Order already processed' }, 409)
      }
    } else {
      // Store the pending order so the webhook can look it up later
      const { error: insertErr } = await adminClient.from('payhere_orders').insert({
        id:            orderId,
        org_id:        orgId,
        user_id:       user.id,
        plan_slug:     planSlug,
        billing_cycle: billingCycle,
        amount:        parseFloat(amount),
        currency,
        status:        'pending',
      })

      if (insertErr) {
        console.error('payhere-hash: failed to store order:', insertErr.message, insertErr.code)
        return json({ error: 'Payment gateway error. Please try again.' }, 500)
      }
    }

    // PayHere hash: MD5(merchantId + orderId + amount + currency + MD5(secret).toUpper).toUpper
    const secretMd5 = md5Upper(merchantSecret)
    const hash      = md5Upper(`${merchantId}${orderId}${amount}${currency}${secretMd5}`)

    // Return the notify URL so Flutter never needs to know the Supabase project URL
    const notifyUrl = `${supabaseUrl}/functions/v1/payhere-notify`

    return json({ hash, merchantId, notifyUrl, checkoutUrl }, 200)
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err)
    console.error('payhere-hash error:', msg)
    return json({ error: 'Unexpected error' }, 500)
  }
})
