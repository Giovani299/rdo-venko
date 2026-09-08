# RDO Venko

Sistema de Relatório Diário de Obra (RDO) da Venko — site estático
(HTML/JS puro, sem build), publicado via GitHub Pages, com backend em
Supabase (Postgres + Auth + Realtime).

Este repositório é **separado** do sistema Venko Serviços (`Venko-servi-os`)
e usa seu próprio projeto Supabase (`rdo-venko`, organização pessoal
`GiovaniNC07`, plano gratuito). Os dados não são compartilhados entre os
dois sistemas.

## Arquivos

- `index.html` — o sistema em si (painel, RDOs, obras, equipamentos, usuários).
- `bootstrap.html` — página de configuração inicial: cria o primeiro
  usuário administrador (só precisa ser usada uma vez, no primeiro acesso).
- `config.js` — credenciais do Supabase (`SUPABASE_URL` e `SUPABASE_ANON_KEY`
  do projeto `rdo-venko`).
- `019_rdo_venko.sql` — migration que cria as tabelas `profiles`, `obras`
  e `rdos` (rodar uma vez no SQL Editor do Supabase).
- `020_equipamentos.sql` — migration que adiciona a tabela `equipamentos`
  (cadastro usado pela aba **Equipamentos**, ver abaixo). Rodar depois da
  `019_rdo_venko.sql`.

## Primeiro acesso

1. Rode as migrations `019_rdo_venko.sql` e `020_equipamentos.sql` no SQL
   Editor do projeto Supabase.
2. Em Authentication → Providers → Email, desligue **Confirm email**
   (os logins usam o domínio fictício `@rdo.venko.local`, que não recebe
   e-mail de confirmação de verdade).
3. Abra `bootstrap.html` no site publicado para criar o primeiro usuário
   administrador.
4. Faça login em `index.html` com esse usuário.

## Aba Equipamentos (cadastro de máquinas)

Além das obras, o sistema tem uma aba **Equipamentos** onde é possível
cadastrar de uma vez as máquinas/equipamentos usados nas obras (ex:
betoneira, grua, andaime, compactador de solo). O cadastro é único,
compartilhado entre todas as obras.

Ao preencher uma RDO, a seção **Equipamentos** passa a oferecer uma lista
de seleção com os itens já cadastrados — e uma opção **"Outro (digitar)…"**
para os casos em que o equipamento usado ainda não está no cadastro
(o texto digitado é salvo normalmente na RDO, só não fica pré-cadastrado
para uso futuro até alguém adicioná-lo na aba Equipamentos).

## Limitações conhecidas

- Fotos das RDOs são salvas como base64 dentro do próprio registro —
  soft cap de ~8 MB por RDO.
- Login não tem recuperação de senha por e-mail de verdade (o domínio é
  fictício); um administrador precisa recadastrar a senha manualmente.
- "Remover acesso" de um usuário é soft-delete (remove o perfil do
  sistema, mas o login no Supabase Auth continua existindo — para apagar
  de vez, use o painel do Supabase em Authentication → Users).
