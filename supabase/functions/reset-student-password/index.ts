// Edge Function: reset-student-password
// Allows teachers to reset a student's password using admin API

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface ResetPasswordRequest {
  studentId: string
  newPassword: string
}

interface ResetPasswordResponse {
  success: boolean
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
    const { studentId, newPassword } = await req.json() as ResetPasswordRequest

    // Validate input
    if (!studentId || !newPassword) {
      throw new Error('Missing required fields: studentId, newPassword')
    }

    if (newPassword.length < 6) {
      throw new Error('Password must be at least 6 characters')
    }

    // Create admin client with service role key
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Verify caller is a teacher/head/admin
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('Missing authorization header')
    }

    const token = authHeader.replace('Bearer ', '')

    // Create client with user's token to verify their role
    const supabaseUser = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      {
        global: {
          headers: { Authorization: `Bearer ${token}` }
        }
      }
    )

    const { data: { user }, error: userError } = await supabaseUser.auth.getUser()
    if (userError || !user) {
      throw new Error('Invalid authorization token')
    }

    // Check if caller has teacher/head/admin role
    const { data: callerProfile, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single()

    if (profileError || !callerProfile) {
      throw new Error('Could not verify user role')
    }

    const allowedRoles = ['teacher', 'head', 'admin']
    if (!allowedRoles.includes(callerProfile.role)) {
      throw new Error('Unauthorized: Only teachers can reset student passwords')
    }

    // Verify target is a student
    const { data: studentProfile, error: studentError } = await supabaseAdmin
      .from('profiles')
      .select('role')
      .eq('id', studentId)
      .single()

    if (studentError || !studentProfile) {
      throw new Error('Student not found')
    }

    if (studentProfile.role !== 'student') {
      throw new Error('Can only reset passwords for students')
    }

    // Update password using admin API
    const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
      studentId,
      { password: newPassword }
    )

    if (updateError) {
      throw updateError
    }

    const response: ResetPasswordResponse = {
      success: true
    }

    return new Response(
      JSON.stringify(response),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )
  } catch (error) {
    const response: ResetPasswordResponse = {
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
