// Edge Function: bulk-create-students
// Creates student and teacher accounts with auto-generated usernames and passwords
// Students get synthetic emails (username@owlio.local) for Supabase Auth

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// --- Interfaces ---

interface StudentInput {
  first_name: string
  last_name: string
  class_name: string
}

interface TeacherInput {
  first_name: string
  last_name: string
  email: string
}

interface RequestBody {
  school_id: string
  students?: StudentInput[]
  teachers?: TeacherInput[]
}

interface CreatedUser {
  first_name: string
  last_name: string
  username?: string
  email?: string
  password: string
  class_name?: string
  role: string
}

interface ErrorEntry {
  first_name: string
  last_name: string
  error: string
}

// --- Password Generation ---

const WORDS = [
  'owl', 'fox', 'sun', 'cat', 'dog', 'bee', 'sky', 'ice', 'red', 'pen',
  'cup', 'hat', 'map', 'box', 'key', 'gem', 'fin', 'pod', 'ray', 'dew',
  'elm', 'oak', 'fig', 'ant', 'bat', 'elk', 'cod', 'ram', 'yak', 'emu',
]

function generatePassword(): string {
  const word = WORDS[Math.floor(Math.random() * WORDS.length)]
  const num = Math.floor(Math.random() * 900) + 100 // 100-999 (always 3 digits)
  return `${word}${num}`
}

// --- CORS ---

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

// --- Main Handler ---

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body: RequestBody = await req.json()
    const { school_id, students = [], teachers = [] } = body

    if (!school_id) {
      return jsonResponse({ error: 'school_id is required' }, 400)
    }

    if (students.length === 0 && teachers.length === 0) {
      return jsonResponse({ error: 'At least one student or teacher is required' }, 400)
    }

    if (students.length > 200) {
      return jsonResponse({ error: 'Maximum 200 students per request' }, 400)
    }

    // Create admin client (service role)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // Verify caller authorization
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return jsonResponse({ error: 'Missing authorization header' }, 401)
    }

    const token = authHeader.replace('Bearer ', '')
    const supabaseUser = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: `Bearer ${token}` } } },
    )

    const { data: { user: caller }, error: authError } = await supabaseUser.auth.getUser()
    if (authError || !caller) {
      return jsonResponse({ error: 'Invalid authentication' }, 401)
    }

    // Check caller role
    const { data: callerProfile } = await supabaseAdmin
      .from('profiles')
      .select('role')
      .eq('id', caller.id)
      .single()

    if (!callerProfile || !['admin', 'head'].includes(callerProfile.role)) {
      return jsonResponse({ error: 'Unauthorized: admin or head role required' }, 403)
    }

    // Verify school exists
    const { data: school } = await supabaseAdmin
      .from('schools')
      .select('id')
      .eq('id', school_id)
      .single()

    if (!school) {
      return jsonResponse({ error: `School not found: ${school_id}` }, 400)
    }

    const created: CreatedUser[] = []
    const errors: ErrorEntry[] = []

    // Class cache to avoid repeated lookups
    const classCache = new Map<string, string>()

    // --- Helper: get or create class ---
    async function getOrCreateClass(className: string): Promise<string> {
      const cached = classCache.get(className)
      if (cached) return cached

      // Try to find existing class first
      const { data: existing } = await supabaseAdmin
        .from('classes')
        .select('id')
        .eq('school_id', school_id)
        .eq('name', className)
        .is('academic_year', null)
        .single()

      if (existing) {
        classCache.set(className, existing.id)
        return existing.id
      }

      // Not found — try to insert
      try {
        const { data: inserted, error } = await supabaseAdmin
          .from('classes')
          .insert({ school_id, name: className })
          .select('id')
          .single()

        if (inserted && !error) {
          classCache.set(className, inserted.id)
          return inserted.id
        }
      } catch {
        // Unique constraint conflict from concurrent insert — fall through to re-fetch
      }

      // Re-fetch (handles race condition where concurrent request created it)
      const { data: refetched } = await supabaseAdmin
        .from('classes')
        .select('id')
        .eq('school_id', school_id)
        .eq('name', className)
        .is('academic_year', null)
        .single()

      if (refetched) {
        classCache.set(className, refetched.id)
        return refetched.id
      }

      throw new Error(`Could not find or create class: ${className}`)
    }

    // --- Process Students ---
    for (const student of students) {
      try {
        if (!student.first_name?.trim() || !student.last_name?.trim()) {
          errors.push({
            first_name: student.first_name || '',
            last_name: student.last_name || '',
            error: 'first_name and last_name are required',
          })
          continue
        }

        if (!student.class_name?.trim()) {
          errors.push({
            first_name: student.first_name,
            last_name: student.last_name,
            error: 'class_name is required',
          })
          continue
        }

        const firstName = student.first_name.trim()
        const lastName = student.last_name.trim()
        const className = student.class_name.trim()

        // Get or create class
        const classId = await getOrCreateClass(className)

        // Duplicate detection
        const { data: existingStudent } = await supabaseAdmin
          .from('profiles')
          .select('id')
          .eq('first_name', firstName)
          .eq('last_name', lastName)
          .eq('school_id', school_id)
          .eq('class_id', classId)
          .limit(1)

        if (existingStudent && existingStudent.length > 0) {
          errors.push({
            first_name: firstName,
            last_name: lastName,
            error: `Duplicate: student already exists in class ${className}`,
          })
          continue
        }

        // Generate username via DB function
        const { data: usernameResult, error: usernameError } = await supabaseAdmin
          .rpc('generate_username', {
            p_first_name: firstName,
            p_last_name: lastName,
          })

        if (usernameError || !usernameResult) {
          errors.push({
            first_name: firstName,
            last_name: lastName,
            error: `Username generation failed: ${usernameError?.message || 'unknown'}`,
          })
          continue
        }

        const username = usernameResult as string
        const password = generatePassword()
        const syntheticEmail = `${username}@owlio.local`

        // Create auth user
        const { data: authData, error: createError } = await supabaseAdmin.auth.admin.createUser({
          email: syntheticEmail,
          password: password,
          email_confirm: true,
          user_metadata: {
            first_name: firstName,
            last_name: lastName,
            role: 'student',
          },
        })

        if (createError || !authData.user) {
          errors.push({
            first_name: firstName,
            last_name: lastName,
            error: `Auth creation failed: ${createError?.message || 'unknown'}`,
          })
          continue
        }

        // Update profile with username (retry on unique violation)
        let finalUsername = username
        let updateSuccess = false
        for (let attempt = 0; attempt < 3; attempt++) {
          const { error: updateError } = await supabaseAdmin
            .from('profiles')
            .update({
              username: finalUsername,
              school_id: school_id,
              class_id: classId,
              email: null, // Clear synthetic email from profiles
              password_plain: password,
            })
            .eq('id', authData.user.id)

          if (!updateError) {
            updateSuccess = true
            break
          }

          // If unique violation on username, regenerate and retry
          if (updateError.code === '23505' && updateError.message.includes('username')) {
            const { data: retryUsername } = await supabaseAdmin
              .rpc('generate_username', { p_first_name: firstName, p_last_name: lastName })
            if (retryUsername) {
              finalUsername = retryUsername as string
              // Also update the auth email to match new username
              await supabaseAdmin.auth.admin.updateUserById(authData.user.id, {
                email: `${finalUsername}@owlio.local`,
              })
            }
          } else {
            errors.push({
              first_name: firstName,
              last_name: lastName,
              error: `Profile update failed: ${updateError.message}`,
            })
            break
          }
        }

        if (!updateSuccess) continue

        created.push({
          first_name: firstName,
          last_name: lastName,
          username: finalUsername,
          password: password,
          class_name: className,
          role: 'student',
        })
      } catch (err) {
        errors.push({
          first_name: student.first_name || '',
          last_name: student.last_name || '',
          error: `Unexpected error: ${(err as Error).message}`,
        })
      }
    }

    // --- Process Teachers ---
    for (const teacher of teachers) {
      try {
        if (!teacher.first_name?.trim() || !teacher.last_name?.trim()) {
          errors.push({
            first_name: teacher.first_name || '',
            last_name: teacher.last_name || '',
            error: 'first_name and last_name are required',
          })
          continue
        }

        if (!teacher.email?.trim()) {
          errors.push({
            first_name: teacher.first_name,
            last_name: teacher.last_name,
            error: 'email is required for teachers',
          })
          continue
        }

        const firstName = teacher.first_name.trim()
        const lastName = teacher.last_name.trim()
        const email = teacher.email.trim().toLowerCase()
        const password = generatePassword()

        // Create auth user with real email
        const { data: authData, error: createError } = await supabaseAdmin.auth.admin.createUser({
          email: email,
          password: password,
          email_confirm: true,
          user_metadata: {
            first_name: firstName,
            last_name: lastName,
            role: 'teacher',
          },
        })

        if (createError || !authData.user) {
          errors.push({
            first_name: firstName,
            last_name: lastName,
            error: `Auth creation failed: ${createError?.message || 'unknown'}`,
          })
          continue
        }

        // Update profile with role, school and password.
        // The handle_new_user trigger hardcodes role='student' to prevent
        // privilege escalation via signup metadata; trusted server paths
        // (this function uses service_role) must set the real role here.
        const { error: updateError } = await supabaseAdmin
          .from('profiles')
          .update({ role: 'teacher', school_id: school_id, password_plain: password })
          .eq('id', authData.user.id)

        if (updateError) {
          errors.push({
            first_name: firstName,
            last_name: lastName,
            error: `Profile update failed: ${updateError.message}`,
          })
          continue
        }

        created.push({
          first_name: firstName,
          last_name: lastName,
          email: email,
          password: password,
          role: 'teacher',
        })
      } catch (err) {
        errors.push({
          first_name: teacher.first_name || '',
          last_name: teacher.last_name || '',
          error: `Unexpected error: ${(err as Error).message}`,
        })
      }
    }

    return jsonResponse({ created, errors })
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 500)
  }
})
