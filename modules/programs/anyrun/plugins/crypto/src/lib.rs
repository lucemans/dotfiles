use abi_stable::std_types::{ROption, RString, RVec};
use anyrun_plugin::*;

#[init]
fn init(_config_dir: RString) {}

#[info]
fn info() -> PluginInfo {
    PluginInfo {
        name: "Crypto".into(),
        icon: "help-about".into(),
    }
}

#[get_matches]
fn get_matches(input: RString) -> RVec<Match> {
    RVec::new()
}

#[handler]
fn handler(_selection: Match) -> HandleResult {
    HandleResult::Close
}
