-- Rename country column to country_code
ALTER TABLE analytics.events
    RENAME COLUMN country TO country_code;

-- Drop the old index
ALTER TABLE analytics.events
    DROP INDEX country_idx;

-- Create new index with the renamed column
ALTER TABLE analytics.events
    ADD INDEX country_code_idx country_code TYPE bloom_filter GRANULARITY 3;