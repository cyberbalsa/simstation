# Contributions and naming

## Incoming contribution policy

Sim Station uses an inbound-equals-outbound model:

- contributors license new engine/runtime code and build tools under MIT;
- contributors license original project documentation under CC BY 4.0;
- contributors license new core-pack art, audio, maps, narrative, and other
  creative material under CC BY-NC-SA 3.0 US;
- changes to an existing third-party or Goon-derived file remain under that
  file's applicable license;
- generated derivatives remain subject to the licenses of their source
  material.

Every commit must include a Developer Certificate of Origin sign-off:

```text
Signed-off-by: Contributor Name <address@example.invalid>
```

The sign-off certifies that the contributor created the contribution or has
the right to submit it under the applicable project license. The project does
not require a copyright-assignment CLA by default.

## Contribution provenance

A contribution containing code, art, audio, maps, writing, fonts, or data from
elsewhere must declare:

- original source URL and immutable revision where possible;
- author and copyright holder as known;
- exact license and required attribution;
- whether the contribution is copied, adapted, traced, sampled, mixed,
  converted, or generated;
- all material changes;
- evidence that the license is compatible with its destination.

Do not submit assets ripped from another game, film, show, recording, website,
or model pack without documented permission. “Found online,” “free,” and “AI
generated” are not licenses. Contributors using generative tools remain
responsible for provenance, rights, disclosure required by the tool, and
avoiding intentionally imitative or infringing output.

Pull requests that add creative assets must update the provenance manifest and
generated credits. Reviewers must reject or quarantine content with explicit
incompatible evidence.

## Upstream contributions

Goonstation-derived changes may be offered upstream only after:

- separating them from unrelated Sim Station work;
- following Goonstation's current contribution rules;
- retaining all contributor attribution;
- confirming the contributor has authority to submit them.

Upstream acceptance does not automatically update Sim Station's pinned source.
The normal reviewed import procedure still applies.

## Codename policy

“Sim Station” is an internal codename. A similar station-building game is
already distributed as
[`SimStation` on itch.io](https://adam4813.itch.io/simstation), so the codename
must not become the public product name without a formal name and trademark
clearance.

Until a permanent name is selected:

- repository and internal namespace references may use `simstation`;
- `org.simstation.*` content IDs are provisional;
- public store pages, domain purchases, social handles, logos, press
  announcements, and trademark filings must not treat the codename as cleared;
- persisted IDs must be separated from display branding so a rename does not
  invalidate saves or mods;
- the rename plan must provide aliases for any provisional public mod IDs.

## Upstream names and marks

“Goonstation,” “Space Station 13,” and “BYOND” may be used factually for
attribution and compatibility explanation. Do not use upstream logos as Sim
Station branding, imply endorsement, or present the project as an official
Goonstation product.

A public release must include a plain no-endorsement statement:

> Sim Station is an independent, noncommercial derivative project. It is not
> endorsed by or affiliated with Goonstation, Space Station 13, or BYOND.
