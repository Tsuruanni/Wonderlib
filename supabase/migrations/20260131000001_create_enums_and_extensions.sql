-- Migration 1: Enable extensions
-- ReadEng (Wonderlib) Database Schema

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- For fuzzy text search

COMMENT ON EXTENSION "uuid-ossp" IS 'UUID generation functions';
COMMENT ON EXTENSION "pg_trgm" IS 'Trigram matching for fuzzy search';

-- Note: We use CHECK constraints instead of ENUM types for flexibility
-- This allows easier modification without ALTER TYPE
