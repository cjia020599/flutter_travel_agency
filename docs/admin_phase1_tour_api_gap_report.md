# Admin Phase 1 Tour API Gap Report

This report is based on Tour module integration using current frontend behavior as baseline.

## Required by UI but inconsistent/missing in responses

- `title` is not guaranteed; some endpoints return `name`.
- `realTourAddress` is not guaranteed; some responses use `address`, `location`, or `city`.
- `reviewCount` is not guaranteed; alternatives seen: `reviews`, `ratingCount`.
- `locationId` is not guaranteed when `location` object exists instead.
- `isFeatured` is inconsistent with `featured`.

## Sent by frontend but backend support uncertain

- `faqs` array (`[{title, content}]`)
- `include` array (`[{title, content}]`)
- `exclude` array (`[{title, content}]`)
- `itinerary` array (`[{title, content}]`)
- `surroundingsEducation` array
- `surroundingsHealth` array
- `surroundingsTransportation` array
- `duration`
- `minPeople`
- `maxPeople`
- `availability`
- `published` (while `status` is also sent)

## Ambiguous enums/value semantics

- `status`: frontend assumes `'publish'` and `'draft'`; backend may store as different variants.
- `availability`: frontend currently uses `'always'` only; no confirmed additional values.

## Practical backend contract recommendation

- Accept both `title` and `name`, but always return `title`.
- Return canonical location fields: `locationId`, `realTourAddress`, `mapLat`, `mapLng`.
- Return canonical metadata: `status`, `isFeatured`, `reviewCount`, `createdAt`.
- Confirm whether structured arrays (`faqs/include/exclude/itinerary/surroundings*`) are persisted.
