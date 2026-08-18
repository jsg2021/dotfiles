#!/usr/bin/env python3
"""Minimal markdown -> Atlassian Document Format converter.

Supports what these tickets need: headings, paragraphs, bullet/ordered lists,
fenced code blocks, pipe tables, and inline code/strong/link marks.
"""
import json
import re
import sys

INLINE = re.compile(
    r'`([^`]+)`'                     # 1: code
    r'|\*\*([^*]+)\*\*'              # 2: strong
    r'|\[([^\]]+)\]\(([^)]+)\)'      # 3,4: link
)


def text_node(text, marks=None):
    node = {'type': 'text', 'text': text}
    if marks:
        node['marks'] = marks
    return node


def inline(text):
    """Parse inline marks. Never emits an empty text node (ADF rejects them)."""
    nodes, pos = [], 0
    for m in INLINE.finditer(text):
        if m.start() > pos:
            nodes.append(text_node(text[pos:m.start()]))
        if m.group(1) is not None:
            nodes.append(text_node(m.group(1), [{'type': 'code'}]))
        elif m.group(2) is not None:
            nodes.append(text_node(m.group(2), [{'type': 'strong'}]))
        else:
            nodes.append(text_node(
                m.group(3), [{'type': 'link', 'attrs': {'href': m.group(4)}}]))
        pos = m.end()
    if pos < len(text):
        nodes.append(text_node(text[pos:]))
    return nodes or [text_node(' ')]


def para(text):
    return {'type': 'paragraph', 'content': inline(text)}


def list_item(text):
    return {'type': 'listItem', 'content': [para(text)]}


def cell(text, header=False):
    return {
        'type': 'tableHeader' if header else 'tableCell',
        'attrs': {},
        'content': [para(text)],
    }


def split_row(line):
    return [c.strip() for c in line.strip().strip('|').split('|')]


def convert(src):
    lines = src.split('\n')
    content, i = [], 0

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if not stripped:
            i += 1
            continue

        # fenced code block
        if stripped.startswith('```'):
            lang = stripped[3:].strip() or None
            i += 1
            buf = []
            while i < len(lines) and not lines[i].strip().startswith('```'):
                buf.append(lines[i])
                i += 1
            i += 1
            node = {'type': 'codeBlock',
                    'content': [text_node('\n'.join(buf) or ' ')]}
            if lang:
                node['attrs'] = {'language': lang}
            content.append(node)
            continue

        # heading
        m = re.match(r'^(#{1,4})\s+(.*)$', stripped)
        if m:
            content.append({
                'type': 'heading',
                'attrs': {'level': len(m.group(1)) + 2},
                'content': inline(m.group(2)),
            })
            i += 1
            continue

        # table: header row, separator row, then body rows
        if stripped.startswith('|') and i + 1 < len(lines) \
                and re.match(r'^\|[\s:|-]+\|$', lines[i + 1].strip()):
            rows = [{'type': 'tableRow',
                     'content': [cell(c, True) for c in split_row(stripped)]}]
            i += 2
            while i < len(lines) and lines[i].strip().startswith('|'):
                rows.append({'type': 'tableRow',
                             'content': [cell(c) for c in split_row(lines[i])]})
                i += 1
            content.append({
                'type': 'table',
                'attrs': {'isNumberColumnEnabled': False, 'layout': 'default'},
                'content': rows,
            })
            continue

        # bullet list
        if re.match(r'^[-*]\s+', stripped):
            items = []
            while i < len(lines) and re.match(r'^[-*]\s+', lines[i].strip()):
                items.append(list_item(re.sub(r'^[-*]\s+', '', lines[i].strip())))
                i += 1
            content.append({'type': 'bulletList', 'content': items})
            continue

        # ordered list
        if re.match(r'^\d+\.\s+', stripped):
            items = []
            while i < len(lines) and re.match(r'^\d+\.\s+', lines[i].strip()):
                items.append(list_item(re.sub(r'^\d+\.\s+', '', lines[i].strip())))
                i += 1
            content.append({'type': 'orderedList',
                            'attrs': {'order': 1}, 'content': items})
            continue

        # paragraph: consecutive non-blank lines that start no other block
        buf = []
        while i < len(lines):
            cur = lines[i].strip()
            if not cur or cur.startswith(('```', '#', '|')) \
                    or re.match(r'^([-*]|\d+\.)\s+', cur):
                break
            buf.append(cur)
            i += 1
        content.append(para(' '.join(buf)))

    return {'type': 'doc', 'version': 1, 'content': content}


if __name__ == '__main__':
    with open(sys.argv[1]) as f:
        doc = convert(f.read())
    with open(sys.argv[2], 'w') as f:
        json.dump(doc, f, indent=2)
    print(f'{sys.argv[2]}: {len(doc["content"])} top-level nodes')
