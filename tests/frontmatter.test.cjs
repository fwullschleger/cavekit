"use strict";
const assert = require("assert");
const { parseFrontmatter, serializeFrontmatter } = require("../scripts/cavekit-tools.cjs");

function parses_basic_frontmatter() {
  const { meta, body } = parseFrontmatter(
    "---\nphase: building\niteration: 3\n---\nhello\nworld\n"
  );
  assert.strictEqual(meta.phase, "building");
  assert.strictEqual(meta.iteration, 3);
  assert.strictEqual(body.trim(), "hello\nworld");
}

function handles_quoted_strings_and_booleans() {
  const { meta } = parseFrontmatter(
    `---\ntitle: "Hello: world"\nflag: true\nother: null\n---\n`
  );
  assert.strictEqual(meta.title, "Hello: world");
  assert.strictEqual(meta.flag, true);
  assert.strictEqual(meta.other, null);
}

function serialize_roundtrip() {
  const meta = { phase: "building", iteration: 7, tags: ["a", "b"] };
  const out = serializeFrontmatter(meta, "body\n");
  const { meta: round } = parseFrontmatter(out);
  assert.strictEqual(round.phase, "building");
  assert.strictEqual(round.iteration, 7);
  assert.deepStrictEqual(round.tags, ["a", "b"]);
}

function serializer_quotes_ambiguous_strings() {
  const meta = { bool_looking: "true", num_looking: "42" };
  const out = serializeFrontmatter(meta);
  assert.ok(out.includes('bool_looking: "true"'));
  assert.ok(out.includes('num_looking: "42"'));
}

module.exports = {
  parses_basic_frontmatter,
  handles_quoted_strings_and_booleans,
  serialize_roundtrip,
  serializer_quotes_ambiguous_strings,
};
