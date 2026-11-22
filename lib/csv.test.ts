import { describe, expect, it } from 'vitest';
import { csvCell, toCsv } from './csv';

describe('CSV export safety', () => {
  it('quotes commas, quotes and newlines', () => {
    expect(csvCell('name, "test"\nnext')).toBe('"name, ""test""\nnext"');
  });
  it('neutralizes spreadsheet formula prefixes', () => {
    expect(csvCell('=HYPERLINK("https://example.com")')).toBe('"\'=HYPERLINK(""https://example.com"")"');
    expect(csvCell('  +1+1')).toBe('"\'  +1+1"');
  });
  it('serializes null and object values predictably', () => {
    expect(csvCell(null)).toBe('""');
    expect(csvCell({ ok: true })).toBe('"{""ok"":true}"');
  });
  it('writes one header and all rows', () => {
    expect(toCsv(['a', 'b'], [[1, 'x'], [2, 'y']])).toBe('"a","b"\r\n"1","x"\r\n"2","y"');
  });
});
