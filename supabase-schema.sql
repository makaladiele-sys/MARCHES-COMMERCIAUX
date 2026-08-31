-- ============================================================
-- MARCHÉ SÉNÉGAL — Schéma Supabase
-- Dashboard d'indicateurs agricoles + chatbot
-- À exécuter dans l'éditeur SQL de ton projet Supabase (une seule fois)
-- ============================================================

-- Extension nécessaire pour les UUID
create extension if not exists "pgcrypto";

-- ------------------------------------------------------------
-- 1. CATÉGORIES DE PRODUITS
-- ------------------------------------------------------------
create table if not exists categories (
  id text primary key,           -- ex: 'cereales', 'maraichage'
  nom text not null,             -- ex: 'Céréales'
  icone text not null default '🌾',
  ordre int not null default 0
);

insert into categories (id, nom, icone, ordre) values
  ('cereales',      'Céréales',        '🌾', 1),
  ('maraichage',     'Maraîchage',      '🥬', 2),
  ('fruits',          'Fruits',           '🍋', 3),
  ('volaille_oeufs',  'Volaille & Œufs',  '🥚', 4),
  ('legumineuses',    'Légumineuses',     '🫘', 5),
  ('betail',           'Bétail & Viande',  '🐐', 6),
  ('peche',            'Pêche',            '🐟', 7)
on conflict (id) do nothing;

-- ------------------------------------------------------------
-- 2. PRODUITS SUIVIS
-- ------------------------------------------------------------
create table if not exists produits (
  id uuid primary key default gen_random_uuid(),
  nom text not null,
  categorie_id text not null references categories(id),
  unite text not null default 'kg',      -- kg, sac 50kg, litre, unité, cageot...
  actif boolean not null default true,
  cree_le timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 3. INDICATEURS (dernière valeur connue par produit)
-- ------------------------------------------------------------
create table if not exists indicateurs (
  id uuid primary key default gen_random_uuid(),
  produit_id uuid not null unique references produits(id) on delete cascade,
  prix_actuel numeric(12,2) not null,
  prix_precedent numeric(12,2),
  marche text not null default 'Moyenne nationale',   -- ex: 'Marché Tilène, Dakar'
  source text not null default 'Saisie manuelle',
  date_maj timestamptz not null default now()
);

-- Variation en % calculée à la volée (pas stockée, toujours cohérente)
create or replace view v_indicateurs as
select
  i.id,
  p.id as produit_id,
  p.nom as produit,
  p.categorie_id,
  c.nom as categorie_nom,
  c.icone as categorie_icone,
  p.unite,
  i.prix_actuel,
  i.prix_precedent,
  case
    when i.prix_precedent is null or i.prix_precedent = 0 then 0
    else round(((i.prix_actuel - i.prix_precedent) / i.prix_precedent) * 100, 2)
  end as variation_pct,
  i.marche,
  i.source,
  i.date_maj
from indicateurs i
join produits p on p.id = i.produit_id
join categories c on c.id = p.categorie_id
where p.actif = true;

-- ------------------------------------------------------------
-- 4. HISTORIQUE DES PRIX (pour les mini-graphiques de tendance)
-- ------------------------------------------------------------
create table if not exists historique_prix (
  id bigserial primary key,
  produit_id uuid not null references produits(id) on delete cascade,
  prix numeric(12,2) not null,
  releve_le date not null default current_date,
  source text
);

create index if not exists idx_historique_produit_date
  on historique_prix (produit_id, releve_le desc);

-- ------------------------------------------------------------
-- 5. ADMINISTRATEURS (qui a le droit de modifier les données)
-- ------------------------------------------------------------
create table if not exists admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  nom text,
  ajoute_le timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 6. SÉCURITÉ (RLS) — lecture publique, écriture réservée aux admins
-- ------------------------------------------------------------
alter table categories       enable row level security;
alter table produits         enable row level security;
alter table indicateurs      enable row level security;
alter table historique_prix  enable row level security;
alter table admins           enable row level security;

-- Lecture publique (le dashboard est public)
create policy "lecture_publique_categories"      on categories       for select using (true);
create policy "lecture_publique_produits"        on produits         for select using (true);
create policy "lecture_publique_indicateurs"     on indicateurs      for select using (true);
create policy "lecture_publique_historique"      on historique_prix  for select using (true);

-- Un admin peut voir la table admins (pour vérifier son propre statut)
create policy "lecture_son_statut_admin" on admins for select
  using (auth.uid() = user_id);

-- Écriture réservée aux comptes présents dans la table admins
create policy "ecriture_admin_produits" on produits
  for all using (exists (select 1 from admins where user_id = auth.uid()))
  with check (exists (select 1 from admins where user_id = auth.uid()));

create policy "ecriture_admin_indicateurs" on indicateurs
  for all using (exists (select 1 from admins where user_id = auth.uid()))
  with check (exists (select 1 from admins where user_id = auth.uid()));

create policy "ecriture_admin_historique" on historique_prix
  for all using (exists (select 1 from admins where user_id = auth.uid()))
  with check (exists (select 1 from admins where user_id = auth.uid()));

-- ============================================================
-- MISE EN ROUTE (à faire une fois le SQL exécuté) :
--
-- 1. Dans Supabase > Authentication > Users, crée ton compte admin
--    (email + mot de passe), ou active "Sign up" et inscris-toi
--    depuis l'app.
--
-- 2. Récupère ton user_id (Authentication > Users > copier l'UUID)
--    puis exécute :
--    insert into admins (user_id, nom) values ('TON-UUID-ICI', 'Makala');
--
-- 3. Ajoute quelques produits de départ, ex :
--    insert into produits (nom, categorie_id, unite) values
--      ('Mil',            'cereales',     'kg'),
--      ('Riz local',      'cereales',     'kg'),
--      ('Oignon',         'maraichage',   'kg'),
--      ('Tomate',         'maraichage',   'kg'),
--      ('Poulet chair',   'volaille_oeufs','kg'),
--      ('Œuf',            'volaille_oeufs','alvéole de 30');
--
--    Puis un premier indicateur par produit, ex :
--    insert into indicateurs (produit_id, prix_actuel, prix_precedent, marche, source)
--    select id, 350, 340, 'Marché Tilène, Dakar', 'Saisie manuelle'
--    from produits where nom = 'Mil';
-- ============================================================
