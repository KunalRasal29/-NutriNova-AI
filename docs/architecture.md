# Architecture

NutriNova AI is organized as a monorepo with a Django REST backend, Flutter mobile client, local Docker Compose infrastructure, and supporting docs/scripts.

Backend apps are split by domain: accounts, profiles, foods, nutrition, meals, recipes, photos, habits, goals, analytics, integrations, and common.

User-owned models inherit from a shared abstract base that includes `user_id`, UUID primary keys, and audit timestamps. Public food database records can be shared, while user-created records include `user_id`.

Nutrition values are stored separately from foods so each nutrient amount can carry its own source type, source name, source reference, serving metadata, and confidence score.

Photo meal analysis records remain pending until explicitly confirmed by a user. Confirmed suggestions can later become meal items, but this first step intentionally does not wire that workflow yet.

