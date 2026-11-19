___TERMS_OF_SERVICE___

By creating or modifying this file you agree to Google Tag Manager's Community
Template Gallery Developer Terms of Service available at
https://developers.google.com/tag-manager/gallery-tos (or such other URL as
Google may provide), as modified from time to time.


___INFO___

{
  "type": "TAG",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "Jobiqo AIR Tracking (server-side)",
  "categories": [
    "CONVERSIONS",
    "ATTRIBUTION"
  ],
  "brand": {
    "id": "brand_dummy",
    "displayName": "Jobiqo"
  },
  "description": "Sends Jobiqo AIR job views and conversions from a server-side GTM container to the Jobiqo AIR Tracking API. Only AIR traffic is tracked. The tag never delays or blocks other tags.",
  "containerContexts": [
    "SERVER"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "RADIO",
    "name": "eventTypeSource",
    "displayName": "Event type",
    "radioItems": [
      {
        "value": "fixed",
        "displayValue": "Fixed event type"
      },
      {
        "value": "variable",
        "displayValue": "From a variable"
      }
    ],
    "simpleValueType": true,
    "defaultValue": "fixed",
    "help": "Choose a fixed event type for this tag, or use a variable (for example a lookup table) to send different event types from one tag."
  },
  {
    "type": "SELECT",
    "name": "eventType",
    "displayName": "",
    "macrosInSelect": false,
    "selectItems": [
      {
        "value": "view",
        "displayValue": "Job view"
      },
      {
        "value": "apply",
        "displayValue": "Apply start"
      },
      {
        "value": "apply_finish",
        "displayValue": "Apply finish"
      },
      {
        "value": "registration_start",
        "displayValue": "Registration start"
      },
      {
        "value": "registration_complete",
        "displayValue": "Registration complete"
      }
    ],
    "simpleValueType": true,
    "defaultValue": "view",
    "enablingConditions": [
      {
        "paramName": "eventTypeSource",
        "paramValue": "fixed",
        "type": "EQUALS"
      }
    ],
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      }
    ],
    "alwaysInSummary": true
  },
  {
    "type": "TEXT",
    "name": "eventTypeVariable",
    "displayName": "",
    "simpleValueType": true,
    "valueHint": "{{Lookup Table - AIR event type}}",
    "help": "A variable that returns one of: view, apply, apply_finish, registration_start, registration_complete. Other values are skipped.",
    "enablingConditions": [
      {
        "paramName": "eventTypeSource",
        "paramValue": "variable",
        "type": "EQUALS"
      }
    ],
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      }
    ],
    "alwaysInSummary": true
  },
  {
    "type": "RADIO",
    "name": "attribution",
    "displayName": "Conversion attribution",
    "radioItems": [
      {
        "value": "session",
        "displayValue": "Same AIR session only (30 minutes of inactivity ends a session)"
      },
      {
        "value": "window",
        "displayValue": "Within an attribution window"
      }
    ],
    "simpleValueType": true,
    "defaultValue": "session",
    "help": "Apply finish and registration events often happen on pages without AIR parameters. The tag then uses the AIR landing URL stored at the job view. This setting decides how long that stored URL may be used.",
    "alwaysInSummary": true
  },
  {
    "type": "SELECT",
    "name": "attributionWindowDays",
    "displayName": "Attribution window",
    "macrosInSelect": false,
    "selectItems": [
      {
        "value": "1",
        "displayValue": "1 day"
      },
      {
        "value": "7",
        "displayValue": "7 days"
      },
      {
        "value": "30",
        "displayValue": "30 days"
      },
      {
        "value": "90",
        "displayValue": "90 days"
      }
    ],
    "simpleValueType": true,
    "defaultValue": "30",
    "enablingConditions": [
      {
        "paramName": "attribution",
        "paramValue": "window",
        "type": "EQUALS"
      }
    ],
    "alwaysInSummary": true
  },
  {
    "type": "CHECKBOX",
    "name": "testMode",
    "checkboxText": "Mark all events as test events",
    "simpleValueType": true,
    "defaultValue": false,
    "help": "Events sent from GTM preview mode are always marked as test (is_test). Tick this to mark every event as test, for example on a staging environment."
  },
  {
    "type": "GROUP",
    "name": "logsGroup",
    "displayName": "Logs settings",
    "groupStyle": "ZIPPY_CLOSED",
    "subParams": [
      {
        "type": "RADIO",
        "name": "logType",
        "displayName": "",
        "radioItems": [
          {
            "value": "no",
            "displayValue": "Do not log"
          },
          {
            "value": "debug",
            "displayValue": "Log to console during debug and preview"
          },
          {
            "value": "always",
            "displayValue": "Always log to console"
          }
        ],
        "simpleValueType": true,
        "defaultValue": "debug"
      }
    ]
  }
]


___SANDBOXED_JS_FOR_SERVER___

// Jobiqo AIR Tracking (server-side)

const sendHttpRequest = require('sendHttpRequest');
const getEventData = require('getEventData');
const getCookieValues = require('getCookieValues');
const setCookie = require('setCookie');
const generateRandom = require('generateRandom');
const getTimestampMillis = require('getTimestampMillis');
const getContainerVersion = require('getContainerVersion');
const logToConsole = require('logToConsole');
const JSON = require('JSON');


// Constants
const TEMPLATE_VERSION = '1.0.0';
const INTEGRATION = 'sgtm';
const ENDPOINT = 'https://air.jobiqo.com/campaign-tracking';
const REQUEST_USER_AGENT = 'jobiqo-air-sgtm/' + TEMPLATE_VERSION;
const REQUEST_TIMEOUT_MS = 2000;
const SESSION_COOKIE = '_air_session';
const LANDING_COOKIE = '_air_url';
const AIR_PARAM = 'air_campaign_item_id=';
const SESSION_TIMEOUT_SECONDS = 1800;
const SESSION_MODE_LANDING_MAX_AGE = 86400;
const VALID_EVENTS = ['view', 'apply', 'apply_finish', 'registration_start', 'registration_complete'];
// Only these events may use the stored landing URL; view and apply must happen on an AIR URL
const FALLBACK_EVENTS = ['apply_finish', 'registration_start', 'registration_complete'];


// Config (defaults keep older tag configurations working)
// Event type: a fixed choice, or a variable such as a lookup table.
// Tags saved before eventTypeSource existed have no source and use eventType.
const eventType = data.eventTypeSource === 'variable' ? data.eventTypeVariable : data.eventType;
const attribution = data.attribution || 'session';
const windowDays = (1 * data.attributionWindowDays) || 30;
const containerVersion = getContainerVersion();
const isPreview = !!(containerVersion && (containerVersion.previewMode || containerVersion.debugMode));
const isTest = isPreview || data.testMode === true;
const logEnabled = data.logType === 'always' || (data.logType !== 'no' && isPreview);


// Helpers
function log(type, details) {
    if (!logEnabled) return;
    details.Name = 'JobiqoAIR';
    details.Type = type;
    details.TemplateVersion = TEMPLATE_VERSION;
    logToConsole(JSON.stringify(details));
}

function isAirUrl(u) {
    return !!u && u.indexOf(AIR_PARAM) !== -1;
}

function cookieOptions(maxAgeSeconds) {
    return {
        domain: 'auto',
        path: '/',
        'max-age': maxAgeSeconds,
        secure: true,
        httpOnly: true,
        samesite: 'Lax'
    };
}

function newSessionId() {
    return getTimestampMillis() + '.' + generateRandom(100000000, 999999999);
}

function skip(reason) {
    log('Skipped', { EventType: eventType, Reason: reason });
    data.gtmOnSuccess();
}


// 1. Validate event type
if (VALID_EVENTS.indexOf(eventType) === -1) {
    return skip('unknown event type "' + eventType + '"');
}


// 2. Read current state
const pageUrl = getEventData('page_location');
const pageIsAir = isAirUrl(pageUrl);
const existingSessionId = getCookieValues(SESSION_COOKIE)[0];
const storedLanding = getCookieValues(LANDING_COOKIE)[0];


// 3. Resolve the AIR landing URL for this event
let url;
let urlSource;

if (pageIsAir) {
    url = pageUrl;
    urlSource = 'page';
} else if (FALLBACK_EVENTS.indexOf(eventType) !== -1 && storedLanding) {
    const sep = storedLanding.indexOf('|');
    const storedSessionId = sep > -1 ? storedLanding.substring(0, sep) : '';
    const storedUrl = sep > -1 ? storedLanding.substring(sep + 1) : '';
    const sameSession = !!existingSessionId && storedSessionId === existingSessionId;

    if (attribution === 'window' || sameSession) {
        url = storedUrl;
        urlSource = 'cookie';
    }
}


// 4. Not AIR traffic: only keep an existing AIR session alive, set nothing new
if (!isAirUrl(url)) {
    if (existingSessionId) {
        setCookie(SESSION_COOKIE, existingSessionId, cookieOptions(SESSION_TIMEOUT_SECONDS));
    }
    return skip('no AIR landing URL for this event');
}


// 5. AIR session (sliding 30-minute expiry)
const sessionId = existingSessionId || newSessionId();
setCookie(SESSION_COOKIE, sessionId, cookieOptions(SESSION_TIMEOUT_SECONDS));

if (eventType === 'view' && urlSource === 'page') {
    const landingMaxAge = attribution === 'window' ? windowDays * 86400 : SESSION_MODE_LANDING_MAX_AGE;
    setCookie(LANDING_COOKIE, sessionId + '|' + url, cookieOptions(landingMaxAge));
}


// 6. Build payload
const body = {
    event_type: eventType,
    session_id: sessionId,
    url: url,
    referrer: getEventData('page_referrer') || '',
    user_agent: getEventData('user_agent') || '',
    integration: INTEGRATION,
    template_version: TEMPLATE_VERSION,
    is_test: isTest
};

const gaClientId = getEventData('client_id');
if (gaClientId) {
    body.ga_client_id = gaClientId;
}


// 7. Send without waiting: this tag must never delay the client response or other tags
log('Request', { EventType: eventType, UrlSource: urlSource, RequestUrl: ENDPOINT, RequestBody: body });

sendHttpRequest(ENDPOINT, (statusCode, headers, response) => {
    const accepted = statusCode >= 200 && statusCode < 300 && (response || '').indexOf('ERROR') === -1;
    log('Response', {
        EventType: eventType,
        Accepted: accepted,
        ResponseStatusCode: statusCode,
        ResponseBody: response
    });
}, {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'User-Agent': REQUEST_USER_AGENT
    },
    timeout: REQUEST_TIMEOUT_MS
}, JSON.stringify(body));

data.gtmOnSuccess();


___SERVER_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "read_event_data",
        "versionId": "1"
      },
      "param": [
        {
          "key": "keyPatterns",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "page_location"
              },
              {
                "type": 1,
                "string": "page_referrer"
              },
              {
                "type": 1,
                "string": "user_agent"
              },
              {
                "type": 1,
                "string": "client_id"
              }
            ]
          }
        },
        {
          "key": "eventDataAccess",
          "value": {
            "type": 1,
            "string": "specific"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "get_cookies",
        "versionId": "1"
      },
      "param": [
        {
          "key": "cookieAccess",
          "value": {
            "type": 1,
            "string": "specific"
          }
        },
        {
          "key": "cookieNames",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "_air_session"
              },
              {
                "type": 1,
                "string": "_air_url"
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "set_cookies",
        "versionId": "1"
      },
      "param": [
        {
          "key": "allowedCookies",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "name"
                  },
                  {
                    "type": 1,
                    "string": "domain"
                  },
                  {
                    "type": 1,
                    "string": "path"
                  },
                  {
                    "type": 1,
                    "string": "secure"
                  },
                  {
                    "type": 1,
                    "string": "session"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "_air_session"
                  },
                  {
                    "type": 1,
                    "string": "*"
                  },
                  {
                    "type": 1,
                    "string": "*"
                  },
                  {
                    "type": 1,
                    "string": "any"
                  },
                  {
                    "type": 1,
                    "string": "any"
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "name"
                  },
                  {
                    "type": 1,
                    "string": "domain"
                  },
                  {
                    "type": 1,
                    "string": "path"
                  },
                  {
                    "type": 1,
                    "string": "secure"
                  },
                  {
                    "type": 1,
                    "string": "session"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "_air_url"
                  },
                  {
                    "type": 1,
                    "string": "*"
                  },
                  {
                    "type": 1,
                    "string": "*"
                  },
                  {
                    "type": 1,
                    "string": "any"
                  },
                  {
                    "type": 1,
                    "string": "any"
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "send_http",
        "versionId": "1"
      },
      "param": [
        {
          "key": "allowedUrls",
          "value": {
            "type": 1,
            "string": "specific"
          }
        },
        {
          "key": "urls",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "https://air.jobiqo.com/*"
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "read_container_data",
        "versionId": "1"
      },
      "param": []
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "all"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios:
- name: view_airLanding_newVisitor_sendsFullPayload
  code: |-
    // First AIR landing: new session, landing URL stored, full payload sent

    runCode(getMockData({}));

    assertApi('gtmOnSuccess').wasCalled();
    assertThat(request.url).isEqualTo(ENDPOINT);
    assertThat(request.body).isEqualTo({
        event_type: 'view',
        session_id: NEW_SESSION,
        url: AIR_URL,
        referrer: REFERRER,
        user_agent: USER_AGENT,
        integration: 'sgtm',
        template_version: '1.0.0',
        is_test: false,
        ga_client_id: GA_CLIENT_ID
    });
    assertThat(request.options.method).isEqualTo('POST');
    assertThat(request.options.headers['User-Agent']).isEqualTo('jobiqo-air-sgtm/1.0.0');
    assertThat(request.options.timeout).isEqualTo(2000);
    assertThat(cookiesSet._air_session.value).isEqualTo(NEW_SESSION);
    assertThat(cookiesSet._air_session.options['max-age']).isEqualTo(1800);
    assertThat(cookiesSet._air_url.value).isEqualTo(NEW_SESSION + '|' + AIR_URL);
    assertThat(cookiesSet._air_url.options['max-age']).isEqualTo(86400);
- name: view_airLanding_existingSession_keepsSession
  code: |-
    // A new AIR landing within an active session keeps the session ID

    cookieJar._air_session = EXISTING_SESSION;

    runCode(getMockData({}));

    assertThat(request.body.session_id).isEqualTo(EXISTING_SESSION);
    assertThat(cookiesSet._air_session.value).isEqualTo(EXISTING_SESSION);
    assertThat(cookiesSet._air_url.value).isEqualTo(EXISTING_SESSION + '|' + AIR_URL);
- name: view_noAir_noSession_nothingSentNoCookies
  code: |-
    // Non-AIR visitor: no request and no cookies at all

    eventData.page_location = OTHER_JOB_URL;

    runCode(getMockData({}));

    assertApi('sendHttpRequest').wasNotCalled();
    assertApi('setCookie').wasNotCalled();
    assertApi('gtmOnSuccess').wasCalled();
- name: view_noAir_existingSession_onlyRefreshesSession
  code: |-
    // AIR visitor browsing another job: session kept alive, nothing sent

    eventData.page_location = OTHER_JOB_URL;
    cookieJar._air_session = EXISTING_SESSION;
    cookieJar._air_url = EXISTING_SESSION + '|' + AIR_URL;

    runCode(getMockData({}));

    assertApi('sendHttpRequest').wasNotCalled();
    assertThat(cookiesSet._air_session.value).isEqualTo(EXISTING_SESSION);
    assertThat(cookiesSet._air_url).isUndefined();
    assertApi('gtmOnSuccess').wasCalled();
- name: apply_airPage_sendsWithoutLandingCookie
  code: |-
    // Apply start on the AIR job page

    cookieJar._air_session = EXISTING_SESSION;

    runCode(getMockData({ eventType: 'apply' }));

    assertThat(request.body.event_type).isEqualTo('apply');
    assertThat(request.body.url).isEqualTo(AIR_URL);
    assertThat(cookiesSet._air_url).isUndefined();
- name: apply_noAirPage_withLandingCookie_notSent
  code: |-
    // Apply on a non-AIR job must not be attributed to the AIR job

    eventData.page_location = OTHER_JOB_URL;
    cookieJar._air_session = EXISTING_SESSION;
    cookieJar._air_url = EXISTING_SESSION + '|' + AIR_URL;

    runCode(getMockData({ eventType: 'apply' }));

    assertApi('sendHttpRequest').wasNotCalled();
    assertApi('gtmOnSuccess').wasCalled();
- name: applyFinish_sameSession_usesStoredUrl
  code: |-
    // Apply finish on a thank-you page within the same AIR session

    eventData.page_location = PLAIN_URL;
    cookieJar._air_session = EXISTING_SESSION;
    cookieJar._air_url = EXISTING_SESSION + '|' + AIR_URL;

    runCode(getMockData({ eventType: 'apply_finish' }));

    assertThat(request.body.event_type).isEqualTo('apply_finish');
    assertThat(request.body.url).isEqualTo(AIR_URL);
    assertThat(request.body.session_id).isEqualTo(EXISTING_SESSION);
- name: applyFinish_otherSession_sessionMode_notSent
  code: |-
    // Stored landing URL from an earlier session is ignored in session mode

    eventData.page_location = PLAIN_URL;
    cookieJar._air_session = EXISTING_SESSION;
    cookieJar._air_url = 'old.session|' + AIR_URL;

    runCode(getMockData({ eventType: 'apply_finish' }));

    assertApi('sendHttpRequest').wasNotCalled();
    assertApi('gtmOnSuccess').wasCalled();
- name: applyFinish_expiredSession_sessionMode_notSent
  code: |-
    // Session cookie expired: no attribution in session mode

    eventData.page_location = PLAIN_URL;
    cookieJar._air_url = EXISTING_SESSION + '|' + AIR_URL;

    runCode(getMockData({ eventType: 'apply_finish' }));

    assertApi('sendHttpRequest').wasNotCalled();
    assertApi('setCookie').wasNotCalled();
- name: applyFinish_expiredSession_windowMode_sendsWithNewSession
  code: |-
    // In window mode the stored URL is used after the session ended

    eventData.page_location = PLAIN_URL;
    cookieJar._air_url = EXISTING_SESSION + '|' + AIR_URL;

    runCode(getMockData({ eventType: 'apply_finish', attribution: 'window' }));

    assertThat(request.body.url).isEqualTo(AIR_URL);
    assertThat(request.body.session_id).isEqualTo(NEW_SESSION);
- name: applyFinish_multipleTimes_allSent
  code: |-
    // No deduplication: every apply finish is sent

    eventData.page_location = PLAIN_URL;
    cookieJar._air_session = EXISTING_SESSION;
    cookieJar._air_url = EXISTING_SESSION + '|' + AIR_URL;

    runCode(getMockData({ eventType: 'apply_finish' }));
    runCode(getMockData({ eventType: 'apply_finish' }));

    assertThat(requestCount).isEqualTo(2);
    assertThat(cookiesSet._air_url).isUndefined();
- name: registrationComplete_sameSession_usesStoredUrl
  code: |-
    // Registration events use the same fallback as apply finish

    eventData.page_location = PLAIN_URL;
    cookieJar._air_session = EXISTING_SESSION;
    cookieJar._air_url = EXISTING_SESSION + '|' + AIR_URL;

    runCode(getMockData({ eventType: 'registration_complete' }));

    assertThat(request.body.event_type).isEqualTo('registration_complete');
    assertThat(request.body.url).isEqualTo(AIR_URL);
- name: windowMode_landingCookieFollowsWindow
  code: |-
    // Landing cookie lifetime follows the selected attribution window

    runCode(getMockData({ attribution: 'window', attributionWindowDays: '90' }));

    assertThat(cookiesSet._air_url.options['max-age']).isEqualTo(90 * 86400);
    assertThat(cookiesSet._air_session.options['max-age']).isEqualTo(1800);
- name: previewMode_marksTest
  code: |-
    // Events from GTM preview are always test events

    containerVersion.previewMode = true;

    runCode(getMockData({}));

    assertThat(request.body.is_test).isTrue();
- name: testModeCheckbox_marksTest
  code: |-
    // Manual test mode marks events as test outside preview

    runCode(getMockData({ testMode: true }));

    assertThat(request.body.is_test).isTrue();
- name: noGaClientId_fieldOmitted
  code: |-
    // Without a GA4 client ID the field is left out

    eventData.client_id = undefined;

    runCode(getMockData({}));

    assertThat(request.body.ga_client_id).isUndefined();
    assertThat(request.body.session_id).isEqualTo(NEW_SESSION);
- name: missingReferrerAndUserAgent_sentAsEmpty
  code: |-
    // Missing optional event data is sent as empty strings

    eventData.page_referrer = undefined;
    eventData.user_agent = undefined;

    runCode(getMockData({}));

    assertThat(request.body.referrer).isEqualTo('');
    assertThat(request.body.user_agent).isEqualTo('');
- name: neverWaitsForAir
  code: |-
    // The tag succeeds immediately, even if AIR never answers

    mock('sendHttpRequest', function(url, callback, options, body) {
        request = { url: url, options: options, body: JSON.parse(body) };
    });

    runCode(getMockData({}));

    assertApi('gtmOnSuccess').wasCalled();
    assertApi('gtmOnFailure').wasNotCalled();
- name: airErrorResponse_tagStillSucceeds
  code: |-
    // AIR errors are only logged, never surfaced as tag failures

    airStatus = 500;
    airResponse = 'ERROR';

    runCode(getMockData({}));

    assertApi('gtmOnSuccess').wasCalled();
    assertApi('gtmOnFailure').wasNotCalled();
- name: unknownEventType_notSent
  code: |-
    // A lookup table without a match must not send anything

    runCode(getMockData({ eventType: undefined }));

    assertApi('sendHttpRequest').wasNotCalled();
    assertApi('setCookie').wasNotCalled();
    assertApi('gtmOnSuccess').wasCalled();
- name: minimalTagConfig_defaultsApply
  code: |-
    // A tag with only an event type uses session attribution and preview logging

    runCode({ eventType: 'view' });

    assertApi('gtmOnSuccess').wasCalled();
    assertThat(cookiesSet._air_url.options['max-age']).isEqualTo(86400);
    assertThat(request.body.is_test).isFalse();
- name: eventTypeFromVariable_usesVariableValue
  code: |-
    // Variable source: the variable's value is the event type

    runCode(getMockData({ eventTypeSource: 'variable', eventType: 'view', eventTypeVariable: 'apply' }));

    assertThat(request.body.event_type).isEqualTo('apply');
- name: eventTypeFixed_ignoresVariableField
  code: |-
    // Fixed source: a leftover variable value is ignored

    runCode(getMockData({ eventTypeSource: 'fixed', eventType: 'view', eventTypeVariable: 'apply' }));

    assertThat(request.body.event_type).isEqualTo('view');
- name: eventTypeVariable_unknownValue_notSent
  code: |-
    // A variable returning an unknown value sends nothing

    runCode(getMockData({ eventTypeSource: 'variable', eventTypeVariable: 'something_else' }));

    assertApi('sendHttpRequest').wasNotCalled();
    assertApi('gtmOnSuccess').wasCalled();
- name: legacyTag_withoutSource_usesEventType
  code: |-
    // A tag saved before the source field existed keeps working

    runCode({ eventType: 'apply' });

    assertThat(request.body.event_type).isEqualTo('apply');
setup: |-
  // Shared test setup for the Jobiqo AIR server-side template

  const JSON = require('JSON');

  const ENDPOINT = 'https://air.jobiqo.com/campaign-tracking';

  // Test data
  const AIR_URL = 'https://www.example-jobboard.nl/vacature/123?air_campaign_item_id=023d1fa2-e9f&utm_campaign=jobiqo-air&utm_source=Talent&utm_medium=aggregator';
  const PLAIN_URL = 'https://www.example-jobboard.nl/sollicitatie/bedankt';
  const OTHER_JOB_URL = 'https://www.example-jobboard.nl/vacature/456';
  const REFERRER = 'https://nl.talent.com/';
  const USER_AGENT = 'Mozilla/5.0 (Test)';
  const GA_CLIENT_ID = '111.222';
  const NOW = 1700000000000;
  const RANDOM = 123456789;
  const NEW_SESSION = NOW + '.' + RANDOM;
  const EXISTING_SESSION = '1699999999000.987654321';

  // Mutable state per test
  let eventData = {
      page_location: AIR_URL,
      page_referrer: REFERRER,
      user_agent: USER_AGENT,
      client_id: GA_CLIENT_ID
  };
  let cookieJar = {};
  let cookiesSet = {};
  let containerVersion = {
      containerId: 'GTM-TEST',
      version: '1',
      debugMode: false,
      previewMode: false
  };
  let request = null;
  let requestCount = 0;
  let airStatus = 200;
  let airResponse = 'OK';

  // Base tag configuration
  function getMockData(overrides) {
      const defaults = {
          eventTypeSource: 'fixed',
          eventType: 'view',
          attribution: 'session',
          attributionWindowDays: '30',
          testMode: false,
          logType: 'debug'
      };

      for (var key in overrides) {
          defaults[key] = overrides[key];
      }

      return defaults;
  }

  // Mocks
  mock('getEventData', function(key) {
      return eventData[key];
  });

  mock('getCookieValues', function(name) {
      return cookieJar[name] ? [cookieJar[name]] : [];
  });

  mock('setCookie', function(name, value, options) {
      cookiesSet[name] = { value: value, options: options };
  });

  mock('getTimestampMillis', function() {
      return NOW;
  });

  mock('generateRandom', function(min, max) {
      return RANDOM;
  });

  mock('getContainerVersion', function() {
      return containerVersion;
  });

  mock('sendHttpRequest', function(url, callback, options, body) {
      request = { url: url, options: options, body: JSON.parse(body) };
      requestCount++;
      callback(airStatus, {}, airResponse);
  });


___NOTES___

Jobiqo AIR Tracking (server-side), template version 1.0.0.
Field name "eventType" matches earlier internal versions, so existing tags keep their configuration.
