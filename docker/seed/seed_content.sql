-- Get user IDs (these will be created by the API)
-- We'll use the handles to find the IDs

-- Create follows relationships using handles
INSERT INTO follows (follower_id, followee_id)
SELECT 
    follower.id as follower_id,
    followee.id as followee_id
FROM users follower
JOIN users followee ON true
WHERE 
    follower.handle = 'demo' AND followee.handle = 'alice'
ON CONFLICT DO NOTHING;

INSERT INTO follows (follower_id, followee_id)
SELECT 
    follower.id as follower_id,
    followee.id as followee_id
FROM users follower
JOIN users followee ON true
WHERE 
    follower.handle = 'demo' AND followee.handle = 'bob'
ON CONFLICT DO NOTHING;

INSERT INTO follows (follower_id, followee_id)
SELECT 
    follower.id as follower_id,
    followee.id as followee_id
FROM users follower
JOIN users followee ON true
WHERE 
    follower.handle = 'alice' AND followee.handle = 'bob'
ON CONFLICT DO NOTHING;

INSERT INTO follows (follower_id, followee_id)
SELECT 
    follower.id as follower_id,
    followee.id as followee_id
FROM users follower
JOIN users followee ON true
WHERE 
    follower.handle = 'bob' AND followee.handle = 'cora'
ON CONFLICT DO NOTHING;

-- Create media using handles
INSERT INTO media (id, owner_id, original_key, thumb_key, medium_key, width, height, bytes, created_at)
SELECT 
    '00000000-0000-0000-0000-000000010001' as id,
    u.id as owner_id,
    'seed/alice/coffee.jpg' as original_key,
    'seed/alice/coffee_thumb.jpg' as thumb_key,
    'seed/alice/coffee_medium.jpg' as medium_key,
    1600 as width,
    1200 as height,
    245000 as bytes,
    now() - interval '3 days' as created_at
FROM users u
WHERE u.handle = 'alice'
ON CONFLICT DO NOTHING;

INSERT INTO media (id, owner_id, original_key, thumb_key, medium_key, width, height, bytes, created_at)
SELECT 
    '00000000-0000-0000-0000-000000010002' as id,
    u.id as owner_id,
    'seed/bob/city.jpg' as original_key,
    'seed/bob/city_thumb.jpg' as thumb_key,
    'seed/bob/city_medium.jpg' as medium_key,
    2000 as width,
    1333 as height,
    310000 as bytes,
    now() - interval '2 days' as created_at
FROM users u
WHERE u.handle = 'bob'
ON CONFLICT DO NOTHING;

INSERT INTO media (id, owner_id, original_key, thumb_key, medium_key, width, height, bytes, created_at)
SELECT 
    '00000000-0000-0000-0000-000000010003' as id,
    u.id as owner_id,
    'seed/cora/plate.jpg' as original_key,
    'seed/cora/plate_thumb.jpg' as thumb_key,
    'seed/cora/plate_medium.jpg' as medium_key,
    1400 as width,
    1400 as height,
    275000 as bytes,
    now() - interval '1 days' as created_at
FROM users u
WHERE u.handle = 'cora'
ON CONFLICT DO NOTHING;

-- Create posts using handles
INSERT INTO posts (id, owner_id, media_id, caption, visibility, created_at)
SELECT 
    '00000000-0000-0000-0000-000000020001' as id,
    u.id as owner_id,
    '00000000-0000-0000-0000-000000010001' as media_id,
    'Morning coffee.' as caption,
    'public' as visibility,
    now() - interval '3 days' as created_at
FROM users u
WHERE u.handle = 'alice'
ON CONFLICT DO NOTHING;

INSERT INTO posts (id, owner_id, media_id, caption, visibility, created_at)
SELECT 
    '00000000-0000-0000-0000-000000020002' as id,
    u.id as owner_id,
    '00000000-0000-0000-0000-000000010002' as media_id,
    'City lights.' as caption,
    'public' as visibility,
    now() - interval '2 days' as created_at
FROM users u
WHERE u.handle = 'bob'
ON CONFLICT DO NOTHING;

INSERT INTO posts (id, owner_id, media_id, caption, visibility, created_at)
SELECT 
    '00000000-0000-0000-0000-000000020003' as id,
    u.id as owner_id,
    '00000000-0000-0000-0000-000000010003' as media_id,
    'Dinner vibes.' as caption,
    'public' as visibility,
    now() - interval '1 days' as created_at
FROM users u
WHERE u.handle = 'cora'
ON CONFLICT DO NOTHING;

-- Create likes using handles
INSERT INTO likes (id, user_id, post_id, created_at)
SELECT 
    '00000000-0000-0000-0000-000000030001' as id,
    u.id as user_id,
    '00000000-0000-0000-0000-000000020001' as post_id,
    now() - interval '2 days' as created_at
FROM users u
WHERE u.handle = 'demo'
ON CONFLICT DO NOTHING;

INSERT INTO likes (id, user_id, post_id, created_at)
SELECT 
    '00000000-0000-0000-0000-000000030002' as id,
    u.id as user_id,
    '00000000-0000-0000-0000-000000020002' as post_id,
    now() - interval '1 days' as created_at
FROM users u
WHERE u.handle = 'demo'
ON CONFLICT DO NOTHING;

INSERT INTO likes (id, user_id, post_id, created_at)
SELECT 
    '00000000-0000-0000-0000-000000030003' as id,
    u.id as user_id,
    '00000000-0000-0000-0000-000000020002' as post_id,
    now() - interval '1 days' as created_at
FROM users u
WHERE u.handle = 'alice'
ON CONFLICT DO NOTHING;

-- Create comments using handles
INSERT INTO comments (id, user_id, post_id, body, created_at)
SELECT 
    '00000000-0000-0000-0000-000000040001' as id,
    u.id as user_id,
    '00000000-0000-0000-0000-000000020001' as post_id,
    'Looks great!' as body,
    now() - interval '2 days' as created_at
FROM users u
WHERE u.handle = 'demo'
ON CONFLICT DO NOTHING;

INSERT INTO comments (id, user_id, post_id, body, created_at)
SELECT 
    '00000000-0000-0000-0000-000000040002' as id,
    u.id as user_id,
    '00000000-0000-0000-0000-000000020003' as post_id,
    'Nice colors.' as body,
    now() - interval '1 days' as created_at
FROM users u
WHERE u.handle = 'bob'
ON CONFLICT DO NOTHING;
