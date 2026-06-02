// PayHere payment notification webhook.
// PayHere POSTs application/x-www-form-urlencoded to this URL after each payment attempt.
// We verify the signature before touching the database.
// Always returns HTTP 200 — PayHere retries on any non-200 response.

import { createClient } from 'npm:@supabase/supabase-js@2'
import { createHash } from 'node:crypto'

function md5Upper(s: string): string {
  return createHash('md5').update(s).digest('hex').toUpperCase()
}

// PayHere status codes
const STATUS = {
  SUCCESS:     '2',
  PENDING:     '0',
  CANCELLED:   '-1',
  FAILED:      '-2',
  CHARGEDBACK: '-3',
} as const

Deno.serve(async (req: Request) => {
  // PayHere only POSTs — reject everything else
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 })
  }

  const supabaseUrl       = Deno.env.get('SUPABASE_URL')!
  const serviceRoleKey    = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const sandboxMerchantId = Deno.env.get('PAYHERE_SANDBOX_MERCHANT_ID') ?? ''

  try {
    const rawBody = await req.text()
    const params  = new URLSearchParams(rawBody)

    const merchantId      = params.get('merchant_id')      ?? ''
    const orderId         = params.get('order_id')         ?? ''
    const paymentId       = params.get('payment_id')       ?? ''
    const payhereAmount   = params.get('payhere_amount')   ?? ''
    const payhereCurrency = params.get('payhere_currency') ?? ''
    const statusCode      = params.get('status_code')      ?? ''
    const md5sig          = params.get('md5sig')           ?? ''

    if (!orderId || !md5sig || !statusCode) {
      console.error('payhere-notify: missing required fields in payload')
      return ok()
    }

    // Select the correct secret based on which merchant account received the payment.
    // Sandbox (localhost/dev) and production have different merchant IDs and secrets.
    const merchantSecret = merchantId === sandboxMerchantId
      ? (Deno.env.get('PAYHERE_SECRET_LOCALHOST') ?? Deno.env.get('PAYHERE_MERCHANT_SECRET')!)
      : Deno.env.get('PAYHERE_MERCHANT_SECRET')!

    // Verify PayHere signature:
    // MD5(merchant_id + order_id + payhere_amount + payhere_currency + status_code + MD5(secret).toUpper).toUpper
    const expectedSig = md5Upper(
      `${merchantId}${orderId}${payhereAmount}${payhereCurrency}${statusCode}${md5Upper(merchantSecret)}`
    )

    if (expectedSig !== md5sig.toUpperCase()) {
      console.error(`payhere-notify: signature mismatch for order ${orderId}. Possible replay/forgery attempt.`)
      return ok() // return 200 so PayHere doesn't flood us with retries, but take no action
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    const dbStatus =
      statusCode === STATUS.SUCCESS     ? 'completed' :
      statusCode === STATUS.PENDING     ? 'pending'   :
      statusCode === STATUS.CANCELLED   ? 'cancelled' :
      'failed'

    // Update the order record
    const { data: order, error: updateErr } = await adminClient
      .from('payhere_orders')
      .update({
        status:             dbStatus,
        payhere_payment_id: paymentId || null,
        updated_at:         new Date().toISOString(),
      })
      .eq('id', orderId)
      .select('org_id, plan_slug, billing_cycle')
      .maybeSingle()

    if (updateErr) {
      console.error(`payhere-notify: failed to update order ${orderId}:`, updateErr.message)
      return ok()
    }

    if (!order) {
      console.error(`payhere-notify: order ${orderId} not found in payhere_orders`)
      return ok()
    }

    // Activate the plan only on confirmed successful payment
    if (statusCode === STATUS.SUCCESS) {
      const { data: org } = await adminClient
        .from('organizations')
        .select('plan')
        .eq('id', order.org_id)
        .maybeSingle()

      if (org && org.plan === order.plan_slug) {
        // Plan unchanged (e.g. enterprise pre-set by superadmin, or paying again
        // mid-trial on the same hero plan). Still flip to active so a trial /
        // trial_expired org has its read-only state lifted.
        const { error: statusErr } = await adminClient
          .from('organizations')
          .update({ status: 'active' })
          .eq('id', order.org_id)

        if (statusErr) {
          console.error(`payhere-notify: failed to activate org ${order.org_id}:`, statusErr.message)
        } else {
          console.log(`payhere-notify: org ${order.org_id} already on plan "${order.plan_slug}", status set active`)
        }
      } else {
        const { error: planErr } = await adminClient
          .from('organizations')
          .update({
            plan:          order.plan_slug,
            billing_cycle: order.billing_cycle,
            // Paid -> active. Also clears 'trialing' / 'trial_expired' so a
            // trial->paid conversion lifts the read-only state immediately.
            status:        'active',
          })
          .eq('id', order.org_id)

        if (planErr) {
          console.error(`payhere-notify: failed to upgrade org ${order.org_id} to ${order.plan_slug}:`, planErr.message)
        } else {
          console.log(`payhere-notify: org ${order.org_id} upgraded to plan "${order.plan_slug}" (${order.billing_cycle}), status active`)
        }
      }

      // For enterprise orgs: always stamp subscription_paid_at on every successful
      // payment. Enterprise orgs are pre-set to 'enterprise' by the superadmin, so
      // the plan change above may be skipped — but we still need to clear the payment wall.
      if (order.plan_slug === 'enterprise') {
        await adminClient
          .from('organizations')
          .update({ subscription_paid_at: new Date().toISOString() })
          .eq('id', order.org_id)
        console.log(`payhere-notify: subscription_paid_at stamped for org ${order.org_id}`)
      }
    }

    return ok()
  } catch (err: unknown) {
    console.error('payhere-notify: unexpected error:', err)
    return ok() // always 200 — never let PayHere retry loop on a crash
  }
})

function ok(): Response {
  return new Response('OK', { status: 200 })
}
