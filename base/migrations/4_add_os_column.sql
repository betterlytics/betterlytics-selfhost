ALTER TABLE analytics.events
    ADD COLUMN IF NOT EXISTS os String DEFAULT '';

ALTER TABLE analytics.events
    ADD INDEX os_idx os TYPE bloom_filter GRANULARITY 3;