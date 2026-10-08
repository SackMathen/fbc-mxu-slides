// SceneRenderer draws the scene JSON the host produces (SceneJSON.swift) on a
// 2D canvas: text, shapes, fills, media stills. It stands in for the Metal
// compositor until the native Windows renderer exists.
(function () {
  const FAMILY_FALLBACKS = {
    helveticaneue: '"Helvetica Neue", "Segoe UI", Arial',
    helvetica: '"Helvetica Neue", Helvetica, "Segoe UI", Arial',
    avenirnext: '"Avenir Next", "Segoe UI", Arial',
    avenir: '"Avenir", "Segoe UI", Arial',
    menlo: 'Menlo, Consolas, "Cascadia Mono", monospace',
    georgia: 'Georgia, "Times New Roman", serif',
    sfpro: '"SF Pro", "Segoe UI Variable Text", "Segoe UI"',
    sfprodisplay: '"SF Pro Display", "Segoe UI Variable Display", "Segoe UI"',
    sfprotext: '"SF Pro Text", "Segoe UI Variable Text", "Segoe UI"',
    futura: 'Futura, "Century Gothic", "Segoe UI"',
    gillsans: '"Gill Sans", "Gill Sans MT", "Segoe UI"',
    palatino: 'Palatino, "Palatino Linotype", "Book Antiqua", serif',
    baskerville: 'Baskerville, "Baskerville Old Face", Georgia, serif',
    timesnewroman: '"Times New Roman", Times, serif',
    arial: 'Arial, "Segoe UI"',
    verdana: 'Verdana, "Segoe UI"',
  };
  const BOLD_WORDS = new Set(['bold', 'black', 'heavy', 'semibold', 'demibold', 'extrabold', 'ultrabold', 'medium']);
  const WEIGHTS = { thin: 100, ultralight: 200, extralight: 200, light: 300, regular: 400, book: 400, medium: 500, semibold: 600, demibold: 600, bold: 700, extrabold: 800, ultrabold: 800, heavy: 800, black: 900 };

  const fontCache = new Map();

  function parseFontName(name) {
    if (fontCache.has(name)) return fontCache.get(name);
    const [familyPart, ...styleParts] = String(name || 'HelveticaNeue').split('-');
    const styleTokens = styleParts.join('-').split(/(?=[A-Z])|[\s_]/).map(t => t.toLowerCase()).filter(Boolean);
    let weight = 400;
    let italic = false;
    for (const token of styleTokens) {
      if (WEIGHTS[token] != null) weight = WEIGHTS[token];
      if (token === 'italic' || token === 'oblique') italic = true;
    }
    if (styleTokens.length === 0) {
      const lower = familyPart.toLowerCase();
      for (const word of BOLD_WORDS) if (lower.endsWith(word)) weight = WEIGHTS[word];
    }
    const key = familyPart.toLowerCase().replace(/[^a-z]/g, '');
    const spaced = familyPart.replace(/([a-z])([A-Z])/g, '$1 $2');
    const family = (FAMILY_FALLBACKS[key] ? FAMILY_FALLBACKS[key] + ', ' : `"${spaced}", `) + '"Segoe UI", system-ui, sans-serif';
    const parsed = { family, weight, italic };
    fontCache.set(name, parsed);
    return parsed;
  }

  function cssColor(color, alphaScale = 1) {
    if (!color) return 'transparent';
    const r = Math.round(Math.min(Math.max(color.r, 0), 1) * 255);
    const g = Math.round(Math.min(Math.max(color.g, 0), 1) * 255);
    const b = Math.round(Math.min(Math.max(color.b, 0), 1) * 255);
    const a = Math.min(Math.max(color.a == null ? 1 : color.a, 0), 1) * alphaScale;
    return `rgba(${r}, ${g}, ${b}, ${a})`;
  }

  class SceneRenderer {
    constructor(canvas, options = {}) {
      this.canvas = canvas;
      this.ctx = canvas.getContext('2d');
      this.mediaURL = options.mediaURL || (id => `/ui/v1/media/${encodeURIComponent(id)}`);
      this.onMediaLoaded = options.onMediaLoaded || null;
      this.images = SceneRenderer.sharedImages;
      this.lastScene = null;
    }

    draw(scene) {
      this.lastScene = scene;
      const ctx = this.ctx;
      const canvas = this.canvas;
      const width = canvas.width, height = canvas.height;
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.clearRect(0, 0, width, height);
      if (!scene) return;
      const scale = Math.min(width / scene.width, height / scene.height);
      const offsetX = (width - scene.width * scale) / 2;
      const offsetY = (height - scene.height * scale) / 2;
      ctx.fillStyle = '#000';
      ctx.fillRect(0, 0, width, height);
      ctx.setTransform(scale, 0, 0, scale, offsetX, offsetY);
      ctx.save();
      ctx.beginPath();
      ctx.rect(0, 0, scene.width, scene.height);
      ctx.clip();
      ctx.fillStyle = cssColor(scene.background);
      ctx.fillRect(0, 0, scene.width, scene.height);
      for (const layer of scene.layers) {
        if (layer.hidden) continue;
        const mattes = new Map(layer.items.filter(i => i.isMatte).map(i => [i.id, i]));
        for (const item of layer.items) {
          if (item.isMatte) continue;
          this.drawItem(ctx, item, mattes, scene);
        }
      }
      ctx.restore();
    }

    drawItem(ctx, item, mattes, scene) {
      const f = item.frame;
      ctx.save();
      ctx.globalAlpha = item.opacity == null ? 1 : item.opacity;
      ctx.globalCompositeOperation = { multiply: 'multiply', screen: 'screen', add: 'lighter' }[item.blendMode] || 'source-over';
      if (item.maskedBy && mattes.has(item.maskedBy) && !item.maskOut) {
        const m = mattes.get(item.maskedBy).frame;
        ctx.beginPath();
        ctx.rect(m.x, m.y, m.width, m.height);
        ctx.clip();
      }
      if (item.rotationDegrees) {
        ctx.translate(f.x + f.width / 2, f.y + f.height / 2);
        ctx.rotate(item.rotationDegrees * Math.PI / 180);
        ctx.translate(-(f.x + f.width / 2), -(f.y + f.height / 2));
      }
      if (item.flipHorizontal || item.flipVertical) {
        ctx.translate(f.x + f.width / 2, f.y + f.height / 2);
        ctx.scale(item.flipHorizontal ? -1 : 1, item.flipVertical ? -1 : 1);
        ctx.translate(-(f.x + f.width / 2), -(f.y + f.height / 2));
      }
      const content = item.content;
      switch (content.type) {
        case 'solid':
          ctx.fillStyle = cssColor(content.color);
          ctx.fillRect(f.x, f.y, f.width, f.height);
          break;
        case 'shape':
          this.drawShape(ctx, content.shape, f);
          break;
        case 'media':
          this.drawMedia(ctx, content.mediaId, content.scaleMode, f);
          break;
        case 'text':
          this.drawText(ctx, content.text, f);
          break;
      }
      ctx.restore();
    }

    shapePath(shape, f) {
      const path = new Path2D();
      switch (shape.kind) {
        case 'ellipse':
          path.ellipse(f.x + f.width / 2, f.y + f.height / 2, f.width / 2, f.height / 2, 0, 0, Math.PI * 2);
          break;
        case 'roundedRectangle': {
          const r = Math.min(shape.cornerRadius || 0, f.width / 2, f.height / 2);
          path.roundRect(f.x, f.y, f.width, f.height, r);
          break;
        }
        case 'path': {
          try {
            const unit = new Path2D(shape.path || '');
            const matrix = new DOMMatrix([f.width, 0, 0, f.height, f.x, f.y]);
            path.addPath(unit, matrix);
          } catch (error) {
            path.rect(f.x, f.y, f.width, f.height);
          }
          break;
        }
        default:
          path.rect(f.x, f.y, f.width, f.height);
      }
      return path;
    }

    fillStyleFor(ctx, fill, f) {
      if (!fill) return null;
      switch (fill.type) {
        case 'solid':
          return cssColor(fill.color);
        case 'linearGradient': {
          const angle = ((fill.angle || 0) - 90) * Math.PI / 180;
          const cx = f.x + f.width / 2, cy = f.y + f.height / 2;
          const half = Math.hypot(f.width, f.height) / 2;
          const dx = Math.cos(angle) * half, dy = Math.sin(angle) * half;
          const gradient = ctx.createLinearGradient(cx - dx, cy - dy, cx + dx, cy + dy);
          for (const stop of fill.stops || []) gradient.addColorStop(Math.min(Math.max(stop.position, 0), 1), cssColor(stop.color));
          return gradient;
        }
        default:
          return null;
      }
    }

    drawShape(ctx, shape, f) {
      const path = this.shapePath(shape, f);
      if (shape.shadow) this.applyShadow(ctx, shape.shadow);
      if (shape.fill && shape.fill.type === 'media') {
        ctx.save();
        ctx.clip(path);
        ctx.globalAlpha *= shape.fillOpacity == null ? 1 : shape.fillOpacity;
        this.drawMedia(ctx, shape.fill.mediaId, shape.fill.scaleMode, f);
        ctx.restore();
      } else {
        const style = this.fillStyleFor(ctx, shape.fill, f);
        if (style) {
          ctx.save();
          ctx.globalAlpha *= shape.fillOpacity == null ? 1 : shape.fillOpacity;
          ctx.fillStyle = style;
          ctx.fill(path);
          ctx.restore();
        }
      }
      ctx.shadowColor = 'transparent';
      if (shape.stroke && shape.stroke.width > 0) {
        ctx.strokeStyle = cssColor(shape.stroke.color);
        ctx.lineWidth = shape.stroke.width;
        ctx.setLineDash(shape.stroke.dash === 'dashed' ? [shape.stroke.width * 3, shape.stroke.width * 2]
          : shape.stroke.dash === 'dotted' ? [shape.stroke.width, shape.stroke.width * 1.5] : []);
        ctx.stroke(path);
        ctx.setLineDash([]);
      }
    }

    applyShadow(ctx, shadow) {
      ctx.shadowColor = cssColor(shadow.color);
      ctx.shadowBlur = shadow.blurRadius;
      ctx.shadowOffsetX = shadow.offsetX;
      ctx.shadowOffsetY = shadow.offsetY;
    }

    image(mediaId) {
      let entry = this.images.get(mediaId);
      if (!entry) {
        const img = new Image();
        entry = { img, ready: false, failed: false, waiting: new Set() };
        img.onload = () => { entry.ready = true; for (const r of entry.waiting) r.redraw(); entry.waiting.clear(); };
        img.onerror = () => { entry.failed = true; entry.waiting.clear(); };
        img.src = this.mediaURL(mediaId);
        this.images.set(mediaId, entry);
      }
      return entry;
    }

    redraw() {
      if (this.lastScene) this.draw(this.lastScene);
      if (this.onMediaLoaded) this.onMediaLoaded();
    }

    drawMedia(ctx, mediaId, scaleMode, f) {
      const entry = this.image(mediaId);
      if (!entry.ready) {
        if (!entry.failed) entry.waiting.add(this);
        ctx.fillStyle = entry.failed ? '#2a2a2a' : '#1c1c1c';
        ctx.fillRect(f.x, f.y, f.width, f.height);
        ctx.fillStyle = 'rgba(255,255,255,0.25)';
        const size = Math.min(f.width, f.height) * 0.18;
        ctx.font = `${size}px "Segoe UI", system-ui, sans-serif`;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(entry.failed ? 'media missing' : 'media', f.x + f.width / 2, f.y + f.height / 2);
        return;
      }
      const img = entry.img;
      const iw = img.naturalWidth || 1, ih = img.naturalHeight || 1;
      let dw = f.width, dh = f.height, dx = f.x, dy = f.y;
      if (scaleMode !== 'stretch') {
        const scale = scaleMode === 'fit' ? Math.min(f.width / iw, f.height / ih) : Math.max(f.width / iw, f.height / ih);
        dw = iw * scale; dh = ih * scale;
        dx = f.x + (f.width - dw) / 2; dy = f.y + (f.height - dh) / 2;
      }
      ctx.save();
      ctx.beginPath();
      ctx.rect(f.x, f.y, f.width, f.height);
      ctx.clip();
      ctx.drawImage(img, dx, dy, dw, dh);
      ctx.restore();
    }

    // Text: wraps words into the frame, shrinks when asked to, honours
    // alignment, insets, line height, tracking, shadow and outline.
    layoutText(ctx, text, f) {
      const font = parseFontName(text.fontName);
      const insetL = text.insetLeft || 0, insetR = text.insetRight || 0, insetT = text.insetTop || 0, insetB = text.insetBottom || 0;
      const width = Math.max(f.width - insetL - insetR - (text.leftIndent || 0) - (text.rightIndent || 0), 1);
      const height = Math.max(f.height - insetT - insetB, 1);
      let string = text.string || '';
      if (text.transform === 'uppercase') string = string.toUpperCase();
      const paragraphs = string.split('\n');
      let fontSize = text.fontSize || 48;
      const minSize = Math.max(text.minFontSize || 12, 8);
      const multiple = text.lineHeightMultiple || 1;

      const measureLayout = (size) => {
        ctx.font = `${font.italic ? 'italic ' : ''}${font.weight} ${size}px ${font.family}`;
        ctx.letterSpacing = `${text.tracking || 0}px`;
        const lineHeight = size * 1.2 * multiple;
        const lines = [];
        let overflowsWord = false;
        paragraphs.forEach((paragraph, p) => {
          const words = paragraph.split(/(\s+)/).filter(w => w.length);
          let line = '';
          const pushLine = (value) => lines.push({ text: value.replace(/\s+$/, ''), paragraph: p });
          if (words.length === 0) { pushLine(''); return; }
          for (const word of words) {
            if (/^\s+$/.test(word)) { if (line) line += ' '; continue; }
            const candidate = line + word;
            if (ctx.measureText(candidate).width <= width || !line) {
              if (!line && ctx.measureText(word).width > width) overflowsWord = true;
              line = candidate;
            } else {
              pushLine(line);
              line = word;
            }
          }
          pushLine(line);
        });
        const totalHeight = lines.length * lineHeight + Math.max(paragraphs.length - 1, 0) * (text.paragraphSpacing || 0);
        return { lines, lineHeight, totalHeight, overflowsWord, size };
      };

      let layout = measureLayout(fontSize);
      if (text.autoShrink) {
        while ((layout.totalHeight > height || (text.keepLinesWhole && layout.overflowsWord)) && fontSize > minSize) {
          fontSize = Math.max(minSize, fontSize * 0.94);
          layout = measureLayout(fontSize);
        }
      }
      return { ...layout, font, width, height, insetL, insetR, insetT, insetB };
    }

    drawText(ctx, text, f) {
      if (!text || !text.string) return;
      const layout = this.layoutText(ctx, text, f);
      const { lines, lineHeight, totalHeight, font, size, insetL, insetT, width, height } = layout;
      ctx.font = `${font.italic ? 'italic ' : ''}${font.weight} ${size}px ${font.family}`;
      ctx.letterSpacing = `${text.tracking || 0}px`;
      ctx.textBaseline = 'alphabetic';
      let y;
      switch (text.verticalAlignment) {
        case 'top': y = f.y + insetT; break;
        case 'bottom': y = f.y + insetT + height - totalHeight; break;
        default: y = f.y + insetT + (height - totalHeight) / 2;
      }
      const align = text.alignment || 'center';
      ctx.textAlign = align === 'left' ? 'left' : align === 'right' ? 'right' : 'center';
      const leftEdge = f.x + insetL + (text.leftIndent || 0);
      const ascent = size * 0.8 * (multipleFor(text));
      const baselineOffset = (lineHeight - size * 1.2) / 2 + ascent;
      let paragraphIndex = 0;
      for (const line of lines) {
        if (line.paragraph !== paragraphIndex) {
          y += (text.paragraphSpacing || 0) * (line.paragraph - paragraphIndex);
          paragraphIndex = line.paragraph;
        }
        let x = align === 'left' ? leftEdge : align === 'right' ? leftEdge + width : leftEdge + width / 2;
        if (line.text) {
          if (text.lineFill) this.drawLineFill(ctx, text, line, x, y, lineHeight, width, leftEdge, size);
          if (text.shadow) this.applyShadow(ctx, text.shadow); else ctx.shadowColor = 'transparent';
          if (text.outline && text.outline.width > 0) {
            ctx.lineJoin = 'round';
            ctx.lineWidth = text.outline.width * 2;
            ctx.strokeStyle = cssColor(text.outline.color);
            ctx.strokeText(line.text, x, y + baselineOffset);
          }
          const fill = text.fill && text.fill.type !== 'none' ? this.fillStyleFor(ctx, text.fill, f) : null;
          ctx.fillStyle = fill || cssColor(text.color);
          ctx.fillText(line.text, x, y + baselineOffset);
          ctx.shadowColor = 'transparent';
          if (text.underline || text.strikethrough) {
            const measured = ctx.measureText(line.text).width;
            const start = align === 'left' ? x : align === 'right' ? x - measured : x - measured / 2;
            ctx.strokeStyle = cssColor(text.color);
            ctx.lineWidth = Math.max(1, size * 0.05);
            ctx.beginPath();
            const ly = text.underline ? y + baselineOffset + size * 0.12 : y + baselineOffset - size * 0.3;
            ctx.moveTo(start, ly); ctx.lineTo(start + measured, ly); ctx.stroke();
          }
        }
        y += lineHeight;
      }
      ctx.letterSpacing = '0px';
    }

    drawLineFill(ctx, text, line, x, y, lineHeight, width, leftEdge, size) {
      const style = text.lineFill;
      const fillStyle = this.fillStyleFor(ctx, style.fill, { x: leftEdge, y, width, height: lineHeight });
      if (!fillStyle) return;
      const measured = ctx.measureText(line.text).width;
      const padX = style.horizontalPadding || 0, padY = style.verticalPadding || 0;
      let bx, bw;
      if (style.widthMode === 'fullWidth') { bx = leftEdge - padX; bw = width + padX * 2; }
      else {
        const start = text.alignment === 'left' ? x : text.alignment === 'right' ? x - measured : x - measured / 2;
        bx = start - padX; bw = measured + padX * 2;
      }
      ctx.save();
      ctx.shadowColor = 'transparent';
      ctx.fillStyle = fillStyle;
      const path = new Path2D();
      path.roundRect(bx + (style.horizontalOffset || 0), y - padY + (style.verticalOffset || 0), bw, lineHeight + padY * 2, style.cornerRadius || 0);
      ctx.fill(path);
      ctx.restore();
    }
  }

  function multipleFor(text) { return 1; }

  SceneRenderer.sharedImages = new Map();
  SceneRenderer.parseFontName = parseFontName;
  SceneRenderer.cssColor = cssColor;
  window.SceneRenderer = SceneRenderer;
})();
