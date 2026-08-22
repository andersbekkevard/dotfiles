---
name: onboard-devbox
description: Onboard a fresh Linux devbox into Anders' dotfiles and Fleet. Use when Anders asks to set up, provision, bootstrap, or onboard a new development machine.
---

# Onboard Devbox

Make the new devbox a working Fleet operator. Do not turn routine setup into a
machine-by-machine ceremony.

1. Install Tailscale locally if absent, run `tailscale up`, and open or surface
   its login URL to Anders. Anders owns the browser authentication.
2. Clone or update `~/dotfiles`, inspect concurrent work, then run
   `./dotfiles.sh install full`. Handle local package and `sudo` requirements;
   do not weaken setup checks to get past them.
3. Run `fleet enroll`. It owns client-key generation, Tailnet identity
   verification, public-key authorization on Europa and the Mac, and connection
   proof. Do not copy a private key or edit `authorized_keys` by hand.
4. Run `./dotfiles.sh agents verify`, `fleet europa check`, and `fleet mac
   check`. Resolve failures before calling the machine onboarded.

Report the machine name, installed profile, Fleet targets proved, and any
remaining browser login or tool-specific authorization. Register the devbox as
an inbound Fleet target only when Anders asks; that is separate from giving it
outbound access to the existing fleet.
