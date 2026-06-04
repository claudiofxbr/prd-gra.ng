ALTER TABLE prds
    ALTER COLUMN stack TYPE text USING stack::text,
    ALTER COLUMN objectives TYPE text USING objectives::text;
