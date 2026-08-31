# Marché Sénégal — Dashboard d'indicateurs agricoles + Assistant

Application en un seul fichier HTML (dashboard + chatbot), sur GitHub Pages + Supabase, comme tes autres projets.

## Ce que contient la livraison

- `index.html` — l'application complète (dashboard + chatbot + admin)
- `supabase-schema.sql` — le schéma de base de données à exécuter une fois
- `supabase/functions/chat-marche/index.ts` — la fonction serveur qui protège ta clé API Claude

## Mise en route (une seule fois)

### 1. Créer le projet Supabase
Sur [supabase.com](https://supabase.com), crée un nouveau projet (gratuit pour démarrer).

### 2. Exécuter le schéma
Dans **SQL Editor**, colle le contenu de `supabase-schema.sql` et exécute-le. Ça crée les tables, la sécurité (RLS), et 7 catégories de produits par défaut.

### 3. Créer ton compte admin
- Dans **Authentication > Users**, crée un utilisateur avec ton e-mail et un mot de passe.
- Copie son UUID.
- Retourne dans **SQL Editor** et exécute :
  ```sql
  insert into admins (user_id, nom) values ('TON-UUID-ICI', 'Makala');
  ```

### 4. Ajouter tes premiers produits
Toujours dans SQL Editor (ou plus tard directement depuis l'app, une fois connecté en admin) :
```sql
insert into produits (nom, categorie_id, unite) values
  ('Mil', 'cereales', 'kg'),
  ('Oignon', 'maraichage', 'kg'),
  ('Poulet chair', 'volaille_oeufs', 'kg');

insert into indicateurs (produit_id, prix_actuel, prix_precedent, marche, source)
select id, 350, 340, 'Marché Tilène, Dakar', 'Saisie manuelle' from produits where nom = 'Mil';
```

### 5. Déployer la fonction du chatbot
Il te faut la [CLI Supabase](https://supabase.com/docs/guides/cli) installée localement.
```bash
supabase login
supabase link --project-ref TON-PROJECT-REF
supabase functions deploy chat-marche
supabase secrets set ANTHROPIC_API_KEY=sk-ant-xxxxxxxx
```
La clé Anthropic reste sur le serveur — elle n'apparaît jamais dans le HTML public.

### 6. Connecter `index.html` à ton projet
Ouvre `index.html`, tout en haut du `<script type="module">`, remplace :
```js
const SUPABASE_URL = 'https://TON-PROJET.supabase.co';
const SUPABASE_ANON_KEY = 'TA-CLE-ANON-PUBLIQUE';
```
par les valeurs de **Project Settings > API** de ton projet Supabase (l'URL et la clé `anon public` — jamais la clé `service_role`).

### 7. Mettre en ligne
Dépose `index.html` sur GitHub Pages comme d'habitude (racine du repo ou `/docs`).

## Comment ça marche au quotidien

- **Dashboard public** : tout le monde voit les prix, les variations en %, les mini-graphiques de tendance et le bandeau défilant — sans connexion.
- **Mise à jour en temps réel réel** : quand un admin modifie un prix, tous les visiteurs connectés voient le changement s'afficher instantanément, sans recharger la page (Supabase Realtime).
- **Admin** (toi) : bouton "Connexion" en haut à droite → une fois connecté, un bouton "+ Produit" apparaît et chaque carte a un bouton "Modifier". Le prix précédent est gardé automatiquement pour calculer la variation.
- **Assistant** : bouton bulle en bas à droite. Il utilise la recherche web à chaque question pour donner l'info la plus fraîche possible, avec ses sources cliquables. C'est un complément aux indicateurs du dashboard, pas une garantie de prix officiel — je l'ai clairement écrit dans le pied de page et dans les consignes de l'assistant lui-même.

## Limite honnête à garder en tête

Il n'existe pas de flux public gratuit donnant du vrai temps réel sur les prix agricoles sénégalais. Le dashboard est donc aussi fiable que ce que toi (ou tes relais terrain) y saisissez — c'est pour ça que la saisie admin est pensée pour être rapide (un champ prix, un clic). L'assistant comble les questions ponctuelles grâce à la recherche web, mais reste transparent quand il ne trouve rien de fiable.
