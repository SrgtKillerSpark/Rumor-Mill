/**
 * Parser for Godot 4 .tscn (text scene) format.
 * Converts the INI-like section structure into a typed node tree.
 */

export interface ExtResource {
  type: string;
  path: string;
  uid?: string;
  id: string;
}

export interface SubResource {
  type: string;
  id: string;
  properties: Record<string, string>;
}

export interface TreeNode {
  name: string;
  type: string;
  script?: string;
  instance?: string;
  children: TreeNode[];
  properties: Record<string, string>;
}

export interface ParsedScene {
  root: TreeNode;
  extResources: ExtResource[];
}

/** Parse a section header line like [tag key="val" key2=val ...] */
function parseSectionHeader(line: string): { tag: string; attrs: Record<string, string> } {
  const inner = line.slice(1, line.lastIndexOf(']')).trim();
  const spaceIdx = inner.search(/\s/);
  const tag = spaceIdx === -1 ? inner : inner.slice(0, spaceIdx);
  const rest = spaceIdx === -1 ? '' : inner.slice(spaceIdx + 1).trim();

  const attrs: Record<string, string> = {};
  let pos = 0;

  while (pos < rest.length) {
    // Skip whitespace
    while (pos < rest.length && /\s/.test(rest[pos])) pos++;
    if (pos >= rest.length) break;

    // Read key (up to '=')
    const keyStart = pos;
    while (pos < rest.length && rest[pos] !== '=') pos++;
    const key = rest.slice(keyStart, pos).trim();
    pos++; // skip '='
    if (!key || pos >= rest.length) break;

    // Read value: quoted string or unquoted (with paren depth tracking)
    let value: string;
    if (rest[pos] === '"') {
      pos++;
      const start = pos;
      while (pos < rest.length && rest[pos] !== '"') {
        if (rest[pos] === '\\') pos++;
        pos++;
      }
      value = rest.slice(start, pos);
      pos++; // skip closing '"'
    } else {
      const start = pos;
      let depth = 0;
      while (pos < rest.length) {
        if (rest[pos] === '(') depth++;
        else if (rest[pos] === ')') { depth--; if (depth < 0) { depth = 0; } }
        else if (/\s/.test(rest[pos]) && depth === 0) break;
        pos++;
      }
      value = rest.slice(start, pos);
    }

    attrs[key] = value;
  }

  return { tag, attrs };
}

/** Extract the resource id from ExtResource("id") or SubResource("id") */
function extractResourceId(value: string): string | undefined {
  const m = value.match(/^(?:ExtResource|SubResource)\("([^"]+)"\)$/);
  return m ? m[1] : undefined;
}

/** Split .tscn content into sections. Each section is [header, ...propertyLines]. */
function splitSections(content: string): Array<{ header: string; lines: string[] }> {
  const sections: Array<{ header: string; lines: string[] }> = [];
  let current: { header: string; lines: string[] } | null = null;

  for (const raw of content.split(/\r?\n/)) {
    const line = raw.trimEnd();
    if (line.startsWith('[') && line.includes(']')) {
      if (current) sections.push(current);
      current = { header: line, lines: [] };
    } else if (current && line.length > 0) {
      current.lines.push(line);
    }
  }
  if (current) sections.push(current);
  return sections;
}

/** Parse raw property lines into a Record<string, string>. */
function parseProperties(lines: string[]): Record<string, string> {
  const props: Record<string, string> = {};
  for (const line of lines) {
    const eqIdx = line.indexOf(' = ');
    if (eqIdx === -1) continue;
    const key = line.slice(0, eqIdx).trim();
    const val = line.slice(eqIdx + 3).trim();
    props[key] = val;
  }
  return props;
}

export function parseTscn(content: string): ParsedScene {
  const sections = splitSections(content);
  const extResources: ExtResource[] = [];
  const subResources: SubResource[] = [];

  // Flat list of parsed node entries before tree assembly
  const nodeEntries: Array<{
    name: string;
    type: string;
    parent: string | null;
    instanceId: string | null;
    properties: Record<string, string>;
  }> = [];

  for (const { header, lines } of sections) {
    const { tag, attrs } = parseSectionHeader(header);

    if (tag === 'ext_resource') {
      extResources.push({
        type: attrs.type ?? '',
        path: attrs.path ?? '',
        uid: attrs.uid,
        id: attrs.id ?? '',
      });
    } else if (tag === 'sub_resource') {
      subResources.push({
        type: attrs.type ?? '',
        id: attrs.id ?? '',
        properties: parseProperties(lines),
      });
    } else if (tag === 'node') {
      // Extract instance attribute from header attrs (ExtResource("id") value)
      const instanceId = attrs.instance ? extractResourceId(attrs.instance) ?? null : null;
      nodeEntries.push({
        name: attrs.name ?? '',
        type: attrs.type ?? '',
        parent: attrs.parent ?? null,
        instanceId,
        properties: parseProperties(lines),
      });
    }
    // gd_scene header is intentionally ignored beyond confirming format
  }

  // Build id->path map for ext_resources (for script resolution)
  const extById = new Map<string, ExtResource>();
  for (const r of extResources) {
    extById.set(r.id, r);
  }

  // Build the node tree from flat list + parent paths
  // Path = parent + "/" + name. Root node has no parent (or parent absent).
  const nodeByPath = new Map<string, TreeNode>();

  let root: TreeNode | null = null;

  for (const entry of nodeEntries) {
    // Resolve script from properties
    let script: string | undefined;
    if (entry.properties['script']) {
      const scriptId = extractResourceId(entry.properties['script']);
      if (scriptId) {
        const res = extById.get(scriptId);
        if (res) script = res.path;
      }
    }

    // Resolve instance path
    let instance: string | undefined;
    if (entry.instanceId) {
      const res = extById.get(entry.instanceId);
      if (res) instance = res.path;
    }

    // Determine node type: instanced nodes may lack explicit type
    const type = entry.type || (instance ? 'PackedScene' : 'Node');

    // Build properties (exclude 'script' since it's promoted to a field)
    const properties: Record<string, string> = {};
    for (const [k, v] of Object.entries(entry.properties)) {
      if (k !== 'script') properties[k] = v;
    }

    const node: TreeNode = {
      name: entry.name,
      type,
      children: [],
      properties,
      ...(script ? { script } : {}),
      ...(instance ? { instance } : {}),
    };

    if (entry.parent === null) {
      // This is the root node
      root = node;
      nodeByPath.set(entry.name, node);
    } else {
      // Compute full path
      const fullPath =
        entry.parent === '.' ? entry.name : `${entry.parent}/${entry.name}`;
      nodeByPath.set(fullPath, node);

      // Find parent node
      const parentNode =
        entry.parent === '.'
          ? root
          : nodeByPath.get(entry.parent) ?? null;

      if (parentNode) {
        parentNode.children.push(node);
      }
    }
  }

  if (!root) {
    throw new Error('No root node found in .tscn content');
  }

  return { root, extResources };
}
