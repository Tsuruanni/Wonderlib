// Edge Function: migrate-student-emails (ONE-TIME)
// Migrates existing students' auth.users.email from real email to synthetic email (username@owlio.local)
// WARNING: This is DESTRUCTIVE — existing students cannot log in with old emails after this runs.
// Must deploy together with Flutter login change.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // Verify caller is admin
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const token = authHeader.replace('Bearer ', '')
    const supabaseUser = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: `Bearer ${token}` } } },
    )

    const { data: { user: caller } } = await supabaseUser.auth.getUser()
    if (!caller) {
      return new Response(
        JSON.stringify({ error: 'Invalid auth' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const { data: callerProfile } = await supabaseAdmin
      .from('profiles')
      .select('role')
      .eq('id', caller.id)
      .single()

    if (!callerProfile || callerProfile.role !== 'admin') {
      return new Response(
        JSON.stringify({ error: 'Admin only' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // Fetch all students with usernames
    const { data: students, error } = await supabaseAdmin
      .from('profiles')
      .select('id, username, email')
      .eq('role', 'student')
      .not('username', 'is', null)

    if (error) throw error

    let migrated = 0
    let skipped = 0
    const errors: string[] = []

    for (const student of students || []) {
      const syntheticEmail = `${student.username}@owlio.local`

      // Skip if already migrated (email is null or already synthetic)
      if (student.email === null || student.email === syntheticEmail) {
        skipped++
        continue
      }

      try {
        // Update auth.users email to synthetic
        const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
          student.id,
          { email: syntheticEmail },
        )

        if (updateError) {
          errors.push(`${student.username}: ${updateError.message}`)
          continue
        }

        // Clear profiles.email (no longer needed for students)
        await supabaseAdmin
          .from('profiles')
          .update({ email: null })
          .eq('id', student.id)

        migrated++
      } catch (err) {
        errors.push(`${student.username}: ${(err as Error).message}`)
      }
    }

    return new Response(
      JSON.stringify({
        total: students?.length || 0,
        migrated,
        skipped,
        errors,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
