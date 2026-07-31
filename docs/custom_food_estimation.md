# Custom food estimation and confirmation

Custom-food estimation is a review aid. It does not create verified nutrition and
is never treated as a laboratory measurement.

## Safe workflow

1. Call `POST /api/foods/custom/estimate/` with a food name, preparation method,
   and serving weight. Structured ingredients can be supplied for a recipe sum.
2. Review the 3–5 reference matches, their source badges, the estimated range,
   confidence, and warnings.
3. Create the private draft with `POST /api/foods/custom/`. Supplying
   `estimated_nutrients` creates an `estimate_ready` food with no loggable
   nutrition values.
4. Edit values with `PATCH /api/foods/custom/{id}/`. Edits move the record to
   `needs_review`; the original suggestion remains unchanged.
5. Confirm either edited values or explicitly accept the estimate using
   `POST /api/foods/custom/{id}/confirm/`.
6. Only a confirmed custom food can be logged. Use
   `POST /api/foods/custom/{id}/log/` to log it immediately.

Ordinary food search and manual meal logging exclude draft and unconfirmed custom
foods. Existing custom foods created before this workflow are migrated as confirmed
manual entries when they already contain nutrition values.

## Endpoints

- `POST /api/foods/custom/estimate/`: stateless deterministic estimate.
- `POST /api/foods/custom/`: create a private draft, reviewed estimate, or direct
  manual entry.
- `GET /api/foods/custom/{id}/`: owner-only details and review state.
- `PATCH /api/foods/custom/{id}/`: edit metadata, serving, ingredients, or review
  values; `reset_to_estimate` clears corrections without confirming them.
- `POST /api/foods/custom/{id}/re-estimate/`: create a new estimate version;
  `reference_food_id` can select a reference explicitly.
- `POST /api/foods/custom/{id}/confirm/`: confirm edited values, or pass
  `use_estimate: true` to accept the estimate explicitly.
- `GET /api/foods/custom/{id}/history/`: immutable owner-only version history.
- `POST /api/foods/custom/{id}/log/`: log a confirmed food and freeze a meal
  nutrition snapshot.

## Estimation rules

- Only active, non-deprecated stored food records are calculation inputs.
- User-custom and AI-estimate sources are excluded from name-based reference
  matching.
- Matching considers normalized names, aliases, fuzzy similarity, preparation
  state, data quality, and core nutrient completeness.
- Suggested values are a quality-weighted combination of up to five references.
  The response also returns minimum, likely, and maximum values when references
  differ.
- Structured recipe estimates sum stored ingredient nutrition and scale it to the
  entered serving weight.
- If no sufficiently similar and nutritionally complete reference is found, the
  response says `Unable to estimate reliably` and requires manual entry.
- Calories calculated with the 4/4/9 protein/carbohydrate/fat comparison are shown
  separately. They do not overwrite label or user-entered calories.

Recipe estimates do not yet model cooking-water changes, oil absorption, discarded
portions, or nutrient loss. A user must review every result before confirmation.

## Privacy and history

Custom foods, estimates, corrections, and version history are scoped to their
creator. Another user receives a not-found response. Each version records the
serving, estimate, references, corrections, confirmed values, warnings, and status.

Meal items keep their own nutrition snapshots. Editing or re-confirming a custom
food later does not change historical meals.
