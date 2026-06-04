-- Corrige possível corrupção introduzida pela V2 (stack::text / objectives::text).
-- O cast JSONB->TEXT no PostgreSQL pode produzir strings com espaços extras ou
-- aspas escapadas que o Jackson não deserializa como List<String>.
-- Esta migração normaliza todos os valores usando jsonb_build_array como referência.

-- stack: re-serializa via JSONB para garantir JSON compacto e válido
UPDATE prds
SET stack = stack::jsonb::text
WHERE stack IS NOT NULL
  AND stack <> ''
  AND stack <> '[]';

-- objectives: idem
UPDATE prds
SET objectives = objectives::jsonb::text
WHERE objectives IS NOT NULL
  AND objectives <> ''
  AND objectives <> '[]';

-- Registros com valor inválido (não parseável como JSON) recebem array vazio
UPDATE prds
SET stack = '[]'
WHERE stack IS NOT NULL
  AND stack <> ''
  AND NOT (stack ~ '^\[.*\]$');

UPDATE prds
SET objectives = '[]'
WHERE objectives IS NOT NULL
  AND objectives <> ''
  AND NOT (objectives ~ '^\[.*\]$');
