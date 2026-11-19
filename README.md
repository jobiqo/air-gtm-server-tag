# Jobiqo AIR Tracking — server-side GTM tag template

Sends job views and conversions from traffic of Jobiqo AIR campaigns to the Jobiqo AIR Tracking API, from a **server-side Google Tag Manager** container.

- Tracks **AIR traffic only**: visits whose landing URL contains `air_campaign_item_id`.
- **Never delays or blocks** other tags: the tag reports success immediately and does not wait for AIR's response.
- Keeps its **own session**, so it works with or without Google Analytics 4.
- Sends **no IP addresses**.

For web (client-side) containers, use [jobiqo-air-tracking-web](https://github.com/jobiqo/air-gtm-web-tag).

## Requirements

- A server-side GTM container with a client that fills the standard event data keys `page_location`, `page_referrer` and `user_agent`. The GA4 client does this.
- The server container must run on a **first-party subdomain** of the website, for example `sst.example.com`. The tag stores its session and landing URL in HTTP cookies. Without a first-party domain, the browser does not send them back, so every event starts a new session and conversions on pages without AIR parameters cannot be attributed.

## Installation

**From the Community Template Gallery:** in your server container, go to Templates → Tag Templates → Search Gallery, search for "Jobiqo AIR Tracking" and add it.

**Manually:** download `template.tpl`, then go to Templates → Tag Templates → New → ⋮ → Import.

## Configuration

| Field | Description |
|---|---|
| Event type | **Fixed event type**: choose `view`, `apply`, `apply_finish`, `registration_start` or `registration_complete` from the dropdown. **From a variable**: select a variable, e.g. a lookup table on Event Name, that returns one of those values. Unknown values are skipped. |
| Conversion attribution | **Same AIR session only** (default): the stored landing URL is used only within the same AIR session (30 minutes of inactivity ends it). **Within an attribution window**: used until the window expires. |
| Attribution window | 1, 7, 30 or 90 days. Shown only in window mode. |
| Mark all events as test events | Sets `is_test` on every event, e.g. on a staging environment. Events from GTM preview are always marked as test. |
| Logs settings | Do not log / log during debug and preview (default) / always log. |

### Example setup

One tag with Event type set to **From a variable**, using a lookup table:

| Event Name (input) | Output |
|---|---|
| `view_vacancy` | `view` |
| `apply_click` | `apply` |
| `application_completed` | `apply_finish` |

Custom trigger:
- Client Name equals `GA4`
- Event Name matches RegEx `^(view_vacancy|apply_click|application_completed)$`
- Optionally a consent condition, e.g. an Event Data variable on `x-ga-gcs` matching your consent requirements.

## How it works

1. **Job view on an AIR landing URL:** the tag starts or continues an AIR session, stores the landing URL in a cookie, and sends a `view`.
2. **Apply start:** sent only when the current page is an AIR landing URL. An apply on another job is not attributed to the AIR job.
3. **Apply finish and registration events:** use the current URL when it has AIR parameters. Otherwise they use the stored landing URL, within the configured attribution.
4. **Visitors without AIR context:** nothing is sent and no cookies are set. An existing AIR session is kept alive.

Every apply finish is sent; there is no deduplication.

### Cookies

| Name | Content | Lifetime |
|---|---|---|
| `_air_session` | Random AIR session ID | 30 minutes, renewed on every tracked event |
| `_air_url` | Session ID and AIR landing URL | 24 hours in session mode; the attribution window in window mode |

Both are first-party, `Secure`, `HttpOnly` and `SameSite=Lax`.

## Request

`POST https://air.jobiqo.com/campaign-tracking` with a JSON body. The request's own `User-Agent` header identifies the integration (`jobiqo-air-sgtm/<version>`); the visitor's user agent is sent in the body.

| Field | Description |
|---|---|
| `event_type` | The configured event type |
| `session_id` | AIR session ID |
| `url` | AIR landing URL, including its query parameters |
| `referrer` | Page referrer from the event data |
| `user_agent` | Visitor's user agent from the event data |
| `integration` | `sgtm` |
| `template_version` | Template version, e.g. `1.0.0` |
| `is_test` | `true` in preview mode or when test mode is on |
| `ga_client_id` | GA4 client ID, only when available |

Example:

```json
{
  "event_type": "view",
  "session_id": "1700000000000.123456789",
  "url": "https://example.com/job-20725?air_campaign_item_id=023d1fa2-e9f&utm_campaign=jobiqo-air&utm_source=Talent&utm_medium=aggregator",
  "referrer": "https://nl.talent.com/",
  "user_agent": "Mozilla/5.0 (...)",
  "integration": "sgtm",
  "template_version": "1.0.0",
  "is_test": false,
  "ga_client_id": "123456789.1700000000"
}
```

## Testing

1. Open the server container in Preview mode, together with Preview mode of the web container.
2. Visit a job page with `?air_campaign_item_id=test` in the URL.
3. In the server preview, check that the tag fired, and under **Console** look for the `Request` and `Response` log lines. `Accepted: true` means AIR accepted the event.
4. Check that the `_air_session` and `_air_url` cookies exist on the website's domain.
5. Complete an application and check that `apply_finish` is sent with the original landing URL.

Events from preview mode are marked `is_test: true`.

The template also contains unit tests: open the template in the template editor, go to **Tests** and click **Run tests**.

## Releasing a new version

1. Edit the template in the GTM template editor, not by hand.
2. Update `TEMPLATE_VERSION` at the top of the code.
3. Run the tests, export the template and replace `template.tpl`.
4. Commit and push.
5. Add the new commit SHA at the top of `versions` in `metadata.yaml`, with change notes, and push again.

The gallery usually picks up the new version within a few days.

## Support

Report problems via the [issues](https://github.com/jobiqo/air-gtm-server-tag/issues) of this repository.

## License

Apache License 2.0, see [LICENSE](LICENSE).
