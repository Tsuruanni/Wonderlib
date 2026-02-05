// Edge Function: check-streak
// Updates user streak and awards bonus XP for milestones

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface CheckStreakRequest {
  userId: string
}

interface CheckStreakResponse {
  success: boolean
  streak?: number
  longestStreak?: number
  streakBroken?: boolean
  streakExtended?: boolean
  bonusXp?: number
  error?: string
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Streak bonus milestones
const STREAK_BONUSES: Record<number, { xp: number; description: string }> = {
  7: { xp: 50, description: '7-day streak bonus!' },
  14: { xp: 100, description: '2-week streak bonus!' },
  30: { xp: 200, description: '30-day streak bonus!' },
  60: { xp: 400, description: '60-day streak bonus!' },
  100: { xp: 1000, description: '100-day streak bonus!' },
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { userId } = await req.json() as CheckStreakRequest

    if (!userId) {
      throw new Error('Missing required field: userId')
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Update streak via stored function
    const { data: streakResult, error: streakError } = await supabase.rpc('update_user_streak', {
      p_user_id: userId
    })

    if (streakError) throw streakError

    const result = streakResult[0]
    let bonusXp = 0

    // Award streak bonuses if streak was extended
    if (result.streak_extended) {
      const bonus = STREAK_BONUSES[result.new_streak]
      if (bonus) {
        // Award bonus XP
        const { error: xpError } = await supabase.rpc('award_xp_transaction', {
          p_user_id: userId,
          p_amount: bonus.xp,
          p_source: `streak_${result.new_streak}_days`,
          p_source_id: null,
          p_description: bonus.description
        })

        if (xpError) {
          console.error('Streak bonus XP error:', xpError)
        } else {
          bonusXp = bonus.xp
        }
      }
    }

    const response: CheckStreakResponse = {
      success: true,
      streak: result.new_streak,
      longestStreak: result.longest_streak,
      streakBroken: result.streak_broken,
      streakExtended: result.streak_extended,
      bonusXp: bonusXp
    }

    return new Response(
      JSON.stringify(response),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )
  } catch (error) {
    const response: CheckStreakResponse = {
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
