%title: seven years of maintaining firefox
%author: landry@openbsd.org
%date: 2017-10-24
%comment: view with textproc/mdp





-> A journey through web (browser) evolution <-
===

-> EuroBSDcon 2017, Paris <-
---

-> Landry Breuil <-
---

---

-> who am i ? <-
===


- french guy living in the woods^Wfar from paris
- sysadmin in GIS field
- OpenBSD developer since 10 years
- Mozilla contributor since 6 years
- Xfce contributor since 11 years
- Xfce/Mozilla port maintainer since a while

---

-> OpenBSD as a desktop <-
===

- use -current and binary packages
- Xfce/GNOME/KDE
- browsers/multimedia/games
- suspend/resume
- perfect fit for dogfooding!

---

-> (Mozilla) Firefox <-
===

- Leading web browser (in OSS communities ?) for a decade or so
- Huge community/infrastructure/codebase
- Hg repository + source imports
- Fast release schedule
- Supported platforms
- Still kicking

---

-> The browser wars <-
===

- Firefox won the second browser war against IE
- But lost the third war to chromium (thanks google)
- firefox vs chromium in 2017
- same memory usage when you add numbers
- sane defaults, politics, trust, habits..

---

-> Mozilla on OpenBSD <-
===

-> rewind to 2010.. <-
---

- OpenBSD 4.6/4.7
- transition from firefox 3 to firefox 3.5/3.6
- works on x86, macppc, sparc64 (alpha?)
- build with system toolchain
- plain old gmake/autohell
- java + lots of npapi plugins
- bazillion patches in the port
- XUL + xulrunner
- Thunderbird, Seamonkey

---

-> Mozilla on OpenBSD <-
===

-> back in 2013.. <-
---

- lots of port build infra cleanup
- (almost) no more patches
- mozilla.port.mk MODULE
- build with clang/gcc4.6 (since 17)
- html5 A/V, WebGL
- no ESR

---

-> Mozilla on OpenBSD <-
===

-> state as of now in 2017 <-
---

- working WebGL, html5 A/V
- not-that-fast-JS
- not-really-working WebRTC
- can enable multiprocess
- mainline (56.0rc3 now) + ESR52 (57 in november)
- TBB available
- XUL as a standalone technology is dead
- Thunderbird still alive
- webextensions, no NPAPI
- only runs on i386/amd64

---

-> Mozilla on OpenBSD <-
===

-> state as of now in 2017 - build <-
---

- build with clang
- own build system via mach/moz.build
- depends on rust since 53
- relies on Gtk3/icu/hunspell/sqlite3/nss/nspr
- bundles/chases closely icu/sqlite3/nss/nspr
- patch jit engine to allocate 140Mb (ASLR?)
- OOMs ? Default limits ?

---

-> Work work work <-
===

-> infrastructure <-
---

- vms on proxmox s/c 32/64 (bare metal before)
- [buildbot](http://buildbot.rhaalovely.net) for central & beta
- [build/package/sign/distribute](https://packages.rhaalovely.net) betas
- everything [public](https://cgit.rhaalovely.net)
- detailed [undeadly article](http://undeadly.org/cgi?action=article&sid=20170425173917)

-> my workflow <-
---

- package (almost) all betas via the port
- work in git branches, merging all around
- cvs/git add/rm dance

---

-> packaging a beta/release <-
===

   # Change MOZILLA_VERSION, adjust deps
   make makesum
   make patch
   # fix/rm/add patches if needed
   make update-patches
   make update-plist
   make port-lib-depends-check
   make package
   pkg_upload
   git commit -m 'XX.0bY' Makefile distinfo
   git push

---

-> buildbot <-
===

- dashboard keeping track of all builds w/logs
- pull hg tip, apply patches, configure, build, package, upload
- nightly build of mozilla-beta, mozilla-central & comm-central
- on amd64/i386/freebsd-amd64
- produce a mozilla package directly usable for testing
- as close as possible from upstream builds
- allows to find regression windows

---

-> relationship with upstream <-
===

- they know we're here (at least FreeBSD and OpenBSD)
- i sorta know who to ask when a problem is in a specific area (IRC helps!)
- not priority platform, but try to not break it (sortof)
- dozens of bugs because nothing exists outside tier1
- *feedback?* on important changes
- trunk builds unpatched (most of the time) since mid-2012
- feeding back patches since 6 years :)
- reporting bugs upstream
- if you encounter a bug, it might not be openbsd-specific
- or i'm not able to deal with it
- who you gonna call ? BMO !

---

-> so what about firefox in -stable ? <-
===

- experiment since 53, amd64 & i386, 6.1 only
- backports from -current, mainline and ESR
- challenging wrt dependencies.. so maybe ESR only in 6.2 ?
- for -stable pkgs in 3 months, 4 users for i386, 44 for amd64 ?
- for beta pkgs in 7 months, 1 user for i386, 33 for amd64

---

-> Portability <-
===




-> what if i use ppc/sparc64 ? <-
---

-> use netsurf ? <-


---

-> Mozilla future <-
===

-> rust <-
---

- new language developed by mozilla, meant to be *safe and concurrent*
- has some popularity outside of mozilla (most loved in 2016 & 2017 on SO)
- cargo as a package manager (intermixed with rust)
- OpenBSD port maintained by semarie@
- released every 6 weeks
- needs bootstrap on a new arch, rustup to update the lang itself
- rust [platform support](https://forge.rust-lang.org/platform-support.html)

---

-> Mozilla future <-
===

-> rust <-
---

- rust was originally meant to be used to [rewrite](https://wiki.mozilla.org/Oxidation) parts of the codebase
- firefox [policy](https://wiki.mozilla.org/Rust_Update_Policy_for_Firefox) to depend on a recent version
- servo: research project, massively parallel engine
- [quantum](https://wiki.mozilla.org/Quantum): migrate features from servo to gecko
  - compositor
  - stylo
  - gpu rendering
  - dom

---

-> Mozilla future on OpenBSD <-
===

- exotic archs, endianess: the boat has sailed, deal with it
- next hurdle: stylo & i386
- massively multiprocess via [e10s](https://wiki.mozilla.org/Electrolysis) project, requires efficient IPC
- sandboxing w/ `pledge()` ?
- needs `sem_open()`, bigger default limits ?
- generally: stuff that gets enabled by default
- need to keep rust working
- rust ABI target issues
- webrtc ? (testing/debug/help needed!)
- arm64 ? (hw/time needed!)

---









-> questions ? <-
===

-> Thx to EuroBSDcon ! <-
---
