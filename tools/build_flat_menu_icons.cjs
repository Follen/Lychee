// Build-time sprite export. Image artwork is generated; no runtime renderer ships.
// Requires sharp. Run with NODE_PATH pointing to the installed package directory.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require('sharp');
const root = path.resolve(__dirname, '..');
const source = path.join(root, 'assets/menu-icons/flat-atlas.png');
const ids = ('character reputation currency talents specialization spellbook professions mounts pets toys heirlooms appearances warband-scenes achievements quests map friends guild group-finder dungeon-finder raid-finder premade-groups pvp journal journeys travelers-log suggested-content journal-dungeons journal-raids tutorials calendar macros settings game-menu great-vault homepin').split(' ');
const labels = Object.fromEntries(JSON.parse(fs.readFileSync(path.join(root,'assets/menu-icons/selection.json'),'utf8')).icons.map(i=>[i.id,i.label]));
labels['great-vault']='宏伟宝库';labels.homepin='固定';
const hash = b => crypto.createHash('sha256').update(b).digest('hex');
async function main() {
    const {data,info} = await sharp(source).ensureAlpha().raw().toBuffer({resolveWithObject:true});
    // Convert the image-generation matte to alpha before resampling the assets.
    for(let i=0;i<data.length;i+=4) {
        if(Math.min(data[i],data[i+2])-data[i+1]>36) data[i]=data[i+1]=data[i+2]=data[i+3]=0;
    }
    const xs=[0,.18,.343,.507,.67,.833,1].map(v=>Math.round(v*info.width));
    const ys=[0,.18,.347,.506,.665,.83,1].map(v=>Math.round(v*info.height));
    const out=path.join(root,'addon/Lychee/Media/MenuIcons');
    const manifest=[],parts=[];
    for(let n=0;n<ids.length;n++) {
        const col=n%6,row=Math.floor(n/6);
        let x0=xs[col+1],x1=xs[col],y0=ys[row+1],y1=ys[row];
        for(let y=ys[row];y<ys[row+1];y++) for(let x=xs[col];x<xs[col+1];x++) {
            if(data[(y*info.width+x)*4+3]>0) { x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y); }
        }
        if(x0>x1||y0>y1) throw new Error('Empty icon '+ids[n]);
        const png=await sharp(data,{raw:{width:info.width,height:info.height,channels:4}})
            .extract({left:x0,top:y0,width:x1-x0+1,height:y1-y0+1})
            .resize(48,48,{fit:'contain',background:'#00000000'})
            .extend({top:8,bottom:8,left:8,right:8,background:'#00000000'}).png().toBuffer();
        const rgba=await sharp(png).raw().toBuffer();
        const header=Buffer.alloc(18);header[2]=2;header.writeUInt16LE(64,12);header.writeUInt16LE(64,14);header[16]=32;header[17]=0x28;
        const bgra=Buffer.from(rgba);
        for(let i=0;i<rgba.length;i+=4) {bgra[i]=rgba[i+2];bgra[i+2]=rgba[i];}
        const tga=Buffer.concat([header,bgra]);
        fs.writeFileSync(path.join(out,ids[n]+'.tga'),tga);
        manifest.push({id:ids[n],label:labels[ids[n]],sha256:hash(tga),size:64,alpha:true});
        const encoded=png.toString('base64'),px=col*172,py=row*112;
        for(const [offset,size] of [[18,28],[66,34],[114,48]]) {
            parts.push(`<svg x="${px+offset}" y="${py+12+(48-size)/2}" width="${size}" height="${size}" viewBox="4.48 4.48 55.04 55.04"><image href="data:image/png;base64,${encoded}" width="64" height="64"/></svg>`);
        }
        parts.push(`<text x="${px+86}" y="${py+85}" fill="#b7bac1" font-family="Microsoft YaHei,sans-serif" font-size="12" text-anchor="middle">${labels[ids[n]]}</text>`);
    }
    const sheet=`<svg xmlns="http://www.w3.org/2000/svg" width="1032" height="672"><rect width="100%" height="100%" fill="#101012"/>${parts.join('')}</svg>`;
    const docs=path.join(root,'docs/architecture');
    await sharp(Buffer.from(sheet)).png().toFile(path.join(docs,'2026-09-10-flat-menu-icons.png'));
    fs.writeFileSync(path.join(docs,'2026-09-10-flat-menu-icons.json'),JSON.stringify({generator:'tools/build_flat_menu_icons.cjs',source:'assets/menu-icons/flat-atlas.png',sourceSha256:hash(fs.readFileSync(source)),style:'Light silver, warm ivory, lychee red. Flat shapes for dark UI.',previewSizes:[28,34,48],icons:manifest},null,2)+'\n');
    fs.writeFileSync(path.join(out,'LICENSE.txt'),'Lychee flat menu icons: generated artwork, 2026-09-10.\nLight silver, ivory and red sprite atlas exported to transparent 64x64 RGBA TGA.\nLegacy IconPark source references remain in the development repository only.\n');
    console.log('Exported '+manifest.length+' transparent flat icons and dark-background preview.');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
