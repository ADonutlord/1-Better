-- ============================================================================
-- 1% Better — End-to-end encrypted chat support
--
-- 1. profiles.e2ee_public_key: base64 X25519 public key, uploaded by the
--    client. Readable by all authenticated users so participants in a
--    conversation can derive the shared secret.
-- 2. messages.message is widened so an AES-GCM encrypted payload (base64 of
--    nonce|ciphertext|mac) fits. Encrypted user text payloads carry an
--    "e1:" prefix; server-generated system/action messages stay plaintext.
-- ============================================================================

alter table public.profiles
  add column if not exists e2ee_public_key text;

alter table public.messages
  drop constraint if exists messages_message_check;

alter table public.messages
  add constraint messages_message_check
  check (char_length(message) <= 8000);
