use std::{
    collections::HashMap,
    fmt::Write as _,
    sync::{Mutex, MutexGuard, PoisonError},
    time::Duration,
};

use serde_json::Value;
use ureq::{Agent, RequestBuilder, typestate::WithoutBody};

use crate::error::Error;

const API: &str = "https://api.github.com";
const CACHE_ENTRIES: usize = 512;
const DEFAULT_PAGE_SIZE: u32 = 30;
// Job logs answer with a redirect to short-lived blob storage. The token is
// never sent there, and no other destination is followed.
const LOG_HOST_SUFFIXES: [&str; 2] = [".actions.githubusercontent.com", ".blob.core.windows.net"];
const MAX_LOG_BYTES: u64 = 64 * 1024 * 1024;
const PAGE_SIZE: usize = 100;

struct Cached {
    etag: String,
    body: Value,
}

/// Read-only GitHub REST client. Every request it can make is a GET.
pub struct GitHub {
    agent: Agent,
    cache: Mutex<HashMap<String, Cached>>,
    token: Option<String>,
}

impl GitHub {
    pub fn new(token: Option<String>) -> Self {
        let agent = Agent::config_builder()
            .http_status_as_error(false)
            .max_redirects(0)
            .timeout_global(Some(Duration::from_mins(1)))
            .user_agent("github-reader")
            .build()
            .into();
        Self {
            agent,
            cache: Mutex::default(),
            token,
        }
    }

    /// GET `path` from the REST API. A repeated path is a conditional request,
    /// and GitHub does not count a 304 answer against the rate limit.
    pub fn get(&self, path: &str) -> Result<Value, Error> {
        let etag = self.cache().get(path).map(|cached| cached.etag.clone());
        let mut request = self.request(path);
        if let Some(etag) = &etag {
            request = request.header("If-None-Match", etag);
        }
        let mut response = request.call()?;
        let status = response.status().as_u16();
        if status == 304
            && let Some(cached) = self.cache().get(path)
        {
            return Ok(cached.body.clone());
        }
        let etag = response
            .headers()
            .get("etag")
            .and_then(|value| value.to_str().ok())
            .map(str::to_owned);
        let text = response.body_mut().read_to_string()?;
        if !(200..300).contains(&status) {
            return Err(status_error(status, &text));
        }
        let body: Value = serde_json::from_str(&text)?;
        if let Some(etag) = etag {
            let mut cache = self.cache();
            if cache.len() >= CACHE_ENTRIES {
                cache.clear();
            }
            cache.insert(
                path.to_owned(),
                Cached {
                    etag,
                    body: body.clone(),
                },
            );
        }
        Ok(body)
    }

    /// The plain-text log of one Actions job.
    pub fn job_log(&self, path: &str) -> Result<String, Error> {
        let mut response = self.request(path).call()?;
        let status = response.status().as_u16();
        if status != 302 {
            let text = response.body_mut().read_to_string()?;
            return Err(status_error(status, &text));
        }
        let location = response
            .headers()
            .get("location")
            .and_then(|value| value.to_str().ok())
            .ok_or_else(|| status_error(status, "the log redirect has no location"))?;
        let host = location
            .strip_prefix("https://")
            .and_then(|rest| rest.split(['/', '?', '#']).next())
            .unwrap_or_default();
        let trusted = !host.contains('@')
            && LOG_HOST_SUFFIXES
                .iter()
                .any(|suffix| host.ends_with(suffix));
        if !trusted {
            return Err(status_error(
                status,
                &format!("the log redirect goes to {host:?}"),
            ));
        }
        let mut log = self.agent.get(location).call()?;
        let status = log.status().as_u16();
        let text = log
            .body_mut()
            .with_config()
            .limit(MAX_LOG_BYTES)
            .lossy_utf8(true)
            .read_to_string()?;
        if (200..300).contains(&status) {
            Ok(text)
        } else {
            Err(status_error(status, &text))
        }
    }

    /// GET every page of a list endpoint, up to `max_pages`. `field` names the
    /// array for endpoints that wrap it in an object.
    pub fn pages(
        &self,
        path: &str,
        field: Option<&str>,
        max_pages: usize,
    ) -> Result<Vec<Value>, Error> {
        let separator = if path.contains('?') { '&' } else { '?' };
        let mut items = Vec::new();
        for page in 1..=max_pages {
            let mut body = self.get(&format!(
                "{path}{separator}per_page={PAGE_SIZE}&page={page}"
            ))?;
            let batch = match field {
                Some(field) => body[field].take(),
                None => body,
            };
            let Value::Array(batch) = batch else {
                return Err(Error::Status {
                    status: 200,
                    message: format!("{path} did not return a list"),
                });
            };
            let last = batch.len() < PAGE_SIZE;
            items.extend(batch);
            if last {
                break;
            }
        }
        Ok(items)
    }

    fn cache(&self) -> MutexGuard<'_, HashMap<String, Cached>> {
        self.cache.lock().unwrap_or_else(PoisonError::into_inner)
    }

    fn request(&self, path: &str) -> RequestBuilder<WithoutBody> {
        let request = self
            .agent
            .get(format!("{API}{path}"))
            .header("Accept", "application/vnd.github+json")
            .header("X-GitHub-Api-Version", "2022-11-28");
        match &self.token {
            Some(token) => request.header("Authorization", format!("Bearer {token}")),
            None => request,
        }
    }
}

/// Percent-encode one URL query value or path segment.
pub fn encode(value: &str) -> String {
    let mut encoded = String::with_capacity(value.len());
    for byte in value.bytes() {
        if byte.is_ascii_alphanumeric() || b"-._~".contains(&byte) {
            encoded.push(char::from(byte));
        } else {
            let _ = write!(encoded, "%{byte:02X}");
        }
    }
    encoded
}

pub fn page_size(limit: Option<u32>) -> u32 {
    limit.unwrap_or(DEFAULT_PAGE_SIZE).clamp(1, 100)
}

fn status_error(status: u16, text: &str) -> Error {
    let message = serde_json::from_str::<Value>(text)
        .ok()
        .and_then(|body| body["message"].as_str().map(str::to_owned))
        .unwrap_or_else(|| text.chars().take(300).collect());
    Error::Status { status, message }
}
