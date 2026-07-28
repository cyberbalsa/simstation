# License architecture

## Project classification

The project deliberately reuses and adapts Goonstation graphics, audio, data,
and design material from pinned commit
`1b2b250abb5be747d55e274de0203a59cfc8da78`.
That commit's root
[`LICENSE`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/LICENSE)
states that the work is licensed under Creative Commons
Attribution-NonCommercial-ShareAlike 3.0 United States. Its
[`README`](https://github.com/goonstation/goonstation/blob/1b2b250abb5be747d55e274de0203a59cfc8da78/README.md#license)
states that all Goonstation contributions use that license and that `tgui` is
generally MIT unless otherwise specified.

Because the shipped game contains NonCommercial material, public project
descriptions must use **source-available**, **public-source**, or
**noncommercial source project**. They must not claim the complete product is
OSI-approved open source. Creative Commons itself generally
[recommends against applying CC licenses to software](https://creativecommons.org/faq/#can-i-apply-a-creative-commons-license-to-software).

This document defines project policy; it is not a legal opinion.

## License matrix

| Material | Project license policy |
|---|---|
| New engine/runtime code and build tools | MIT, with SPDX identifier `MIT`, unless the file says otherwise |
| New project documentation | CC BY 4.0, with SPDX identifier `CC-BY-4.0`, unless it embeds or adapts differently licensed material |
| New core-pack art, audio, maps, fiction, and other creative content intended to combine with Goon-derived content | CC BY-NC-SA 3.0 US, recorded as `CC-BY-NC-SA-3.0-US` |
| Pinned Goonstation code, data, graphics, audio, maps, and adaptations | CC BY-NC-SA 3.0 US, subject to stronger file-specific notices |
| Generated atlases, converted audio, thumbnails, and other derivatives containing Goon content | CC BY-NC-SA 3.0 US, with transformation provenance |
| Goonstation `tgui` material, if ever imported | MIT unless the imported file specifies otherwise; import is not currently planned |
| Third-party libraries and assets | Their upstream license, preserved file by file; incompatibility blocks bundling |
| Facts-only generated manifests and indexes | MIT for project-authored structure/code, without attempting to relicense embedded third-party content or attribution |

New files must carry a valid SPDX header where the file format allows it.
Binary assets must carry their license and provenance in the asset manifest.
The repository must eventually include canonical license texts under
`LICENSES/` and a root license overview that points to this matrix.

Separately licensed files remain separately identified. The presence of
MIT-licensed engine code does not remove the NonCommercial and ShareAlike
conditions on the Goon-derived content distributed with it.

## CC BY-NC-SA release obligations

For every Goonstation-derived asset, code fragment, data definition, or
adaptation, releases must:

1. **Attribute.** Credit Goonstation and its contributors, link the pinned
   source and applicable license, preserve supplied author and source
   information, and include more specific credits when known.
2. **Identify changes.** Record source path and revision plus the material
   changes made by extraction, re-atlasing, metadata normalization, editing,
   mixing, conversion, or other adaptation.
3. **Remain noncommercial.** Do not sell the Goon-derived distribution, gate it
   behind payment, support it with advertising, bundle it into a paid product,
   or authorize a commercial platform release without separate legal review
   and permissions.
4. **Share alike.** License adaptations of covered material under
   CC BY-NC-SA 3.0 US or a license confirmed compatible with it. Project policy
   uses the same license rather than attempting compatibility substitutions.
5. **Preserve notices.** Ship the license text, attribution, source links,
   copyright notices, and provenance manifests.
6. **Avoid extra restrictions.** Do not apply DRM, effective technological
   measures, or terms that prevent recipients from exercising the licensed
   rights in the covered material.
7. **Avoid endorsement claims.** Attribution must not imply that Goonstation,
   its contributors, BYOND, or Space Station 13 endorses Sim Station.

The project preserves editable source graphics and original audio in the
public source repository as an engineering policy. That policy improves
traceability; it is not a claim that CC BY-NC-SA has a software-style
corresponding-source requirement.

## Distribution boundaries

Release packages contain:

- MIT-licensed original runtime and tools needed by the package;
- compiled Goon-derived graphics and audio content;
- licenses and attribution;
- generated third-party notices, SBOM, and asset provenance.

Release packages omit bulky immutable upstream/authoring sources when those
sources are available from the public repository and are not required at
runtime. The notices must link the exact public source revision and pinned
upstream commit.

A `core-free` build that omits all Goon-derived content may be distributed
under the licenses of its remaining files, but it must use placeholder content
whose provenance permits that distribution. Producing such a build does not
change the license of the normal bundled game.

## Prohibited release states

A release fails legal validation if:

- any shipped file lacks a known license basis;
- a file-specific notice conflicts with the intended distribution;
- a required attribution or license text is missing;
- generated output cannot be traced to source inputs and transformations;
- an asset has explicit incompatible rights evidence;
- notices or the SBOM do not match the shipped artifact hashes;
- branding presents the project as endorsed by an upstream party;
- the release is commercial or contains technical restrictions inconsistent
  with the covered license.
