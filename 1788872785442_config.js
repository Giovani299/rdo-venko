/* =====================================================================
   CONFIGURAÇÃO — preencha estes dois valores antes de publicar.
   Onde encontrar: painel do Supabase > Project Settings > API.
   - SUPABASE_URL       = "Project URL"
   - SUPABASE_ANON_KEY  = a chave "anon public" (NÃO a "service_role")
   A chave anon é pública por natureza (fica visível em qualquer site que
   use Supabase) — a segurança real vem das regras de RLS definidas no
   schema.sql, não do sigilo dessa chave.
   Este arquivo é usado tanto pelo index.html quanto pelo bootstrap.html
   — edite só aqui, uma vez.

   Projeto: rdo-venko (organização pessoal GiovaniNC07, plano Free)
   Este projeto é SEPARADO do projeto usado por Venko-servi-os
   (xchgmuyrackxtplcyjow) — dados não são compartilhados entre os dois.
   ===================================================================== */
var SUPABASE_URL = "https://rbpjwhyoxyybxllshrwd.supabase.co";
var SUPABASE_ANON_KEY = "sb_publishable_g914dVKL8MV2oiTNREVCCw_pSUnnfVh";
var LOGIN_DOMAIN = "rdo.venko.local"; // domínio falso só pra satisfazer o formato de e-mail do Supabase Auth

var CONFIG_OK = /^https?:\/\//.test(SUPABASE_URL) && SUPABASE_ANON_KEY.length > 20;
