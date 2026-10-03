use std::fmt::Write as _;

use serde_json::Value;

const MAX_OUTPUT_BYTES: usize = 120_000;

/// Lenient reads of GitHub JSON: a missing or null field renders as empty.
pub trait Field {
    fn count(&self, key: &str) -> u64;
    fn login(&self, key: &str) -> &str;
    fn names(&self, key: &str) -> String;
    fn short_sha(&self, key: &str) -> &str;
    fn text(&self, key: &str) -> &str;
}

impl Field for Value {
    fn count(&self, key: &str) -> u64 {
        self[key].as_u64().unwrap_or_default()
    }

    fn login(&self, key: &str) -> &str {
        self[key]["login"].as_str().unwrap_or("ghost")
    }

    fn names(&self, key: &str) -> String {
        self[key]
            .as_array()
            .map(|items| {
                items
                    .iter()
                    .filter_map(|item| item["name"].as_str().or_else(|| item["login"].as_str()))
                    .collect::<Vec<_>>()
                    .join(", ")
            })
            .unwrap_or_default()
    }

    fn short_sha(&self, key: &str) -> &str {
        let sha = self.text(key);
        sha.get(..7).unwrap_or(sha)
    }

    fn text(&self, key: &str) -> &str {
        self[key].as_str().unwrap_or_default()
    }
}

/// Cut `output` to a size an agent context can hold.
pub fn bounded(mut output: String) -> String {
    if output.len() > MAX_OUTPUT_BYTES {
        output.truncate(output.floor_char_boundary(MAX_OUTPUT_BYTES));
        output.push_str("\n\n[output truncated]\n");
    }
    output
}

/// Append one comment, review, or review comment under its own heading.
pub fn push_comment(out: &mut String, comment: &Value, detail: &str) {
    let body = comment.text("body").trim();
    let at = match comment.text("submitted_at") {
        "" => comment.text("created_at"),
        submitted => submitted,
    };
    let _ = writeln!(
        out,
        "### @{}{detail} at {at}\n{}\n",
        comment.login("user"),
        if body.is_empty() { "(no text)" } else { body },
    );
}
