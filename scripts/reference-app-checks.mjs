import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

export const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const require = createRequire(path.join(root, '../flare-core-examples/apps/flare-core-web-app/package.json'));
const ts = require('typescript');
const { parse } = require('@vue/compiler-sfc');
const postcss = require('postcss');
const uiPackage = JSON.parse(fs.readFileSync(path.join(root, '../flare-im-design/packages/vue-im-ui/package.json'), 'utf8'));
const exports = new Set(Object.keys(uiPackage.exports).map(key => key === '.' ? '@flare-im/vue-ui' : `@flare-im/vue-ui/${key.slice(2)}`));
const roots = [
  'examples/shared/vue-reference',
  ...['web', 'tauri'].map(platform => `../flare-core-examples/apps/flare-core-${platform}-app/src`),
  '../flare-core-examples/apps/flare-core-flutter-app/lib',
  '../flare-core-examples/apps/flare-core-android-app/app/src/main',
  '../flare-core-examples/apps/flare-core-ios-app/Sources',
];
const extensions = new Set(['.ts', '.vue', '.css', '.scss', '.dart', '.kt', '.swift']);
const excluded = new Set(['node_modules', '.git', 'build', '.build', 'dist', '.dart_tool']);

export function sources() {
  const files = [];
  function visit(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      if (excluded.has(entry.name)) continue;
      const file = path.join(directory, entry.name);
      if (entry.isDirectory()) visit(file);
      else if (extensions.has(path.extname(file)) && !/\.(test|spec)\./.test(file)) files.push(file);
    }
  }
  for (const directory of roots) visit(path.join(root, directory));
  return files.sort().map(file => ({ file: path.relative(root, file), source: fs.readFileSync(file, 'utf8') }));
}

export function checkPublicApi(file, source) {
  const errors = [];
  const check = specifier => {
    if (specifier.startsWith('@flare-im/vue-ui') && !exports.has(specifier)) errors.push(`non-public Vue export: ${specifier}`);
    if (/package:flare_im_ui\/(?!flare_im_ui\.dart$)/.test(specifier)) errors.push(`non-public Flutter import: ${specifier}`);
    if (/flare-im-design\/packages\/[^/]+\/(src|lib|Sources)\//.test(specifier)) errors.push(`direct implementation import: ${specifier}`);
  };
  if (/\.(ts|vue)$/.test(file)) {
    const descriptor = file.endsWith('.vue') ? parse(source).descriptor : null;
    const scripts = descriptor ? [descriptor.script?.content, descriptor.scriptSetup?.content].filter(Boolean) : [source];
    for (const script of scripts) {
      const ast = ts.createSourceFile(file, script, ts.ScriptTarget.Latest, true);
      function visit(node) {
        if ((ts.isImportDeclaration(node) || ts.isExportDeclaration(node)) && node.moduleSpecifier && ts.isStringLiteral(node.moduleSpecifier)) check(node.moduleSpecifier.text);
        if (ts.isCallExpression(node) && (node.expression.kind === ts.SyntaxKind.ImportKeyword || node.expression.getText(ast) === 'require')) {
          if (node.arguments[0] && ts.isStringLiteral(node.arguments[0])) check(node.arguments[0].text);
        }
        ts.forEachChild(node, visit);
      }
      visit(ast);
    }
  } else {
    for (const match of source.matchAll(/(?:import|export)\s+['"]([^'"]+)['"]/g)) check(match[1]);
    if (/import\s+com\.flare\.im\.ui\.(?:internal|impl|private)\b/.test(source)) errors.push('private Compose implementation import');
    if (/@_(?:spi|implementationOnly)[^\n]*import\s+FlareIMUI/.test(source)) errors.push('private Swift UI import');
  }
  return errors;
}

const isDebug = file => /(?:SdkLab|SDKLab|sdk_lab|sdk-lab|diagnostics|DebugView)/.test(file);

// Geometry that only exists at runtime. `AppIcon` renders a glyph at a pixel size
// it receives as a prop and `WorkbenchOverlay` sizes its panel from `width` /
// `height` props — there is no class that can express an arbitrary number, so the
// inline-style rule below cannot be satisfied by correct code here. Both style
// their OWN root element, never a kit component; any other file that reaches for
// `:style` still fails.
const ownsDynamicGeometry = file => /(?:AppIcon|WorkbenchOverlay)\.vue$/.test(file);

export function checkDuplicateUi(file, source) {
  if (isDebug(file)) return [];
  const errors = [];
  // Adapters may retain names like MessageRow, but may not declare a second primitive.
  const declarations = /\b(?:class|struct|object|fun|function)\s+(?:_?)(MessageBubble|VoiceMessage|VoiceCard|AudioView|FileCard|ImageCard|StickerView|ConversationHeader|HeaderIconButton|FlarePanel|FlareType|FlareThemeTokens)\b/g;
  for (const match of source.matchAll(declarations)) errors.push(`local reusable UI declaration: ${match[1]}`);
  if (file.endsWith('.vue')) {
    const template = parse(source).descriptor.template?.content ?? '';
    for (const match of template.matchAll(/<(n-?(?:modal|button|select|dropdown|input|progress|tag))\b/gi)) errors.push(`local generic presentation: ${match[1]}`);
  }
  return [...new Set(errors)];
}

export function checkStyleOwnership(file, source) {
  const errors = [];
  const descriptor = file.endsWith('.vue') ? parse(source).descriptor : null;
  const styles = descriptor ? descriptor.styles.map(style => style.content) : /\.(css|scss)$/.test(file) ? [source] : [];
  for (const style of styles) {
    try {
      postcss.parse(style).walkRules(rule => {
        if (/:deep|::v-deep|\.(?:flare-|message-|composer-|conversation-)/.test(rule.selector)) errors.push(`public/reusable selector override: ${rule.selector}`);
      });
      postcss.parse(style).walkDecls(declaration => { if (declaration.important) errors.push(`important override: ${declaration.prop}`); });
    } catch (error) { errors.push(`unparseable stylesheet: ${error.message}`); }
  }
  if (isDebug(file)) return errors;
  if (!ownsDynamicGeometry(file) && descriptor?.template && /\s:?(?:style)=/.test(descriptor.template.content)) errors.push('inline reusable presentation requires ownership review');
  if (/\.(dart|kt)$/.test(file)) {
    if (/\bColor\(0[xX][0-9a-fA-F]+\)/.test(source)) errors.push('local literal color palette');
    if (/TextStyle\([^)]*fontSize\s*[:=]\s*\d/s.test(source)) errors.push('local literal typography');
  }
  if (file.endsWith('.swift')) {
    if (/Color\(\s*(red:|white:|hue:)/.test(source)) errors.push('local literal color palette');
    if (/(?:Font|\.font\()[^\n]*\.system\(size:\s*\d/.test(source)) errors.push('local literal typography');
    if (/\bstruct\s+\w+\s*:\s*ViewModifier/.test(source)) errors.push('local reusable presentation modifier');
  }
  return [...new Set(errors)];
}

export function runCheck(name, check) {
  const files = sources();
  const findings = files.flatMap(({ file, source }) => check(file, source).map(reason => ({ file, reason })));
  if (process.argv.includes('--json')) console.log(JSON.stringify({ name, files: files.length, findings }, null, 2));
  else {
    console.log(`${name}: ${files.length} source files; ${findings.length} findings`);
    for (const item of findings) console.error(`${item.file}: ${item.reason}`);
  }
  if (findings.length) process.exitCode = 1;
}
