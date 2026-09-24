//
// Version.swift
// Part of Sitrep, a tool for analyzing Swift projects.
//
// Copyright (c) 2020 Hacking with Swift
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See LICENSE for license information
//

/// The version reported by `sitrep --version`: the most recent release.
///
/// This is the single source of truth for the version, and `mise run release`
/// is the only thing that should change it. That task writes the new version
/// here, commits it, and tags that commit, so the tag is always derived from
/// this file and can never disagree with it. Do not edit this by hand.
let sitrepVersion = "4.1.0"
