ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS modifiers JSONB DEFAULT '[]'::jsonb;
