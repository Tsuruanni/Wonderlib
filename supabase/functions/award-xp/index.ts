// Edge Function: award-xp
// Awards XP to a user and checks for new badges

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface AwardXPRequest {
  userId: string
  amount: number
  source: string
  sourceId?: string
  description?: string
}

interface AwardXPResponse {
  success: boolean
  data?: {
    newXp: number
    newLevel: number
    levelUp: boolean
  }
  newBadges?: Array<{
    badgeId: string
    badgeName: string
    xpReward: number
  }>
  error?: string
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { userId, amount, source, sourceId, description } = await req.json() as AwardXPRequest

    // Validate input
    if (!userId || !amount || !source) {
      throw new Error('Missing required fields: userId, amount, source')
    }

    if (amount <= 0) {
      throw new Error('Amount must be positive')
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Award XP via stored function
    const { data: xpResult, error: xpError } = await supabase.rpc('award_xp_transaction', {
      p_user_id: userId,
      p_amount: amount,
      p_source: source,
      p_source_id: sourceId || null,
      p_description: description || null
    })

    if (xpError) throw xpError

    const result = xpResult[0]

    // Check for new badges
    const { data: newBadges, error: badgeError } = await supabase.rpc('check_and_award_badges', {
      p_user_id: userId
    })

    if (badgeError) {
      console.error('Badge check error:', badgeError)
      // Don't fail the whole request for badge errors
    }

    const response: AwardXPResponse = {
      success: true,
      data: {
        newXp: result.new_xp,
        newLevel: result.new_level,
        levelUp: result.level_up
      },
      newBadges: newBadges?.map((b: any) => ({
        badgeId: b.badge_id,
        badgeName: b.badge_name,
        xpReward: b.xp_reward
      })) || []
    }

    return new Response(
      JSON.stringify(response),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )
  } catch (error) {
    const response: AwardXPResponse = {
      success: false,
      error: error.message
    }

    return new Response(
      JSON.stringify(response),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      }
    )
  }
})
