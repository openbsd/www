%title: taming the fox
%author: landry@openbsd.org
%date: 2022-08-18
%comment: view with textproc/mdp

-> Taming the fox <-
===

-> EuroBSDcon 2022, Vienna <-
---

-> Landry Breuil <-
---

---

-> who am i ? <-
===


* french guy living in the woods^Wfar from paris
* sysadmin/devops in GIS field

* OpenBSD developer since 16 years
* Mozilla contributor since 12 years
* Xfce contributor since 17 years
* Xfce/Mozilla port maintainer since a while
* geo/ subdir maintainer since 13 years

---

-> today's topic - taming the fox <-
===


* eurobsdcon 2017 mozilla presentation said: 'sandboxing w/ `pledge()` ?'
* WebRTC was also a challenge ..

* adding `pledge()` was pretty easy at the beginning ...
* ... but took some years to fully get there :)
* and lots of hair pulling/scratching

* learnt tons about internals and code layout
* [searchfox](https://searchfox.org) was a great help

---

-> Mozilla on OpenBSD, as of now <-
===


* ports:
    - `www/mozilla-firefox` 104.2.0 (105 tuesday)
    - `www/firefox-esr` 102.2.1 (102.3 tuesday)
    - `mail/mozilla-thunderbird` 102.2.2
    - `www/tor-browser/browser`
* *-stable* backports (when possible) since 6.1

* depends on rust, llvm, wasi-sysroot, cbindgen..
* working WebRTC, WASM, WebGL, etc...
* main/content/GPU/RDD/socket(webrtc)/utility processes

---

-> Sandboxing ? <-
===


* pledge/unveil, seccomp, capsicum, landlock...
* limit what a process can do (capabilities, syscalls)
* limit system resources usage
* limit what a process can see about others
* limit where a process can read/write
* -> *prevent unwanted access to sensitive files* <-
* ~/.ssh, gpg keys, /etc/master.passwd, kdbx files...

---

-> Existing sandboxing in Mozilla <-
===


* [wiki.mo](https://wiki.mozilla.org/Security/Sandbox)
* maintained upstream on Tier1 platforms
* by [process type](https://firefox-source-docs.mozilla.org/dom/ipc/process_model.html)
* closely linked to multiprocess work in Electrolysis/Fission
* super fine-grained ..
* .. but super complicated:
    - _MacOS_: 2k lines (trustedbsd mac)
    - _Win_: 3k lines
    - _Linux_: 10k lines (seccomp-bpf)

---

-> OpenBSD: pledge()/unveil() <-
===


* [pledge](http://man.openbsd.org/pledge)
    - `pledge(promises)`
    - `pledge("")` -> only computation on memory shared with another process
    - promises can only be tightened, not widened
    - SIGABRT

* [unveil](http://man.openbsd.org/unveil)
    - `unveil(path, mode)`
    - `unveil(NULL, NULL)` -> no more changes allowed
    - ENOENT/EACCESS

* when to call them in the process lifecycle ?
* by-process
* a process cant 'know' if it has limitations

---

-> pledge() promise 'classes' <-
===


* syscalls subsets, with limitations/exceptions (BYPASSUNVEIL)

* promises used by firefox main process:
    - *stdio* / *rpath* / *cpath* / *wpath* / *tmppath*
    - *inet* / *dns* / *unix*
    - *recvfd* / *sendfd* / *exec* / *proc*
    - *ps* / *vminfo* / *prot_exec*
    - *flock* / *fattr* / *tty* / *drm* / *getpw*
    - *video* / *route* / *mcast*

* more available..
    - *audio* / *pf* / *wroute* / *chown* / *settime* / *id*

---

-> pledge() examples in ports/base <-
===


* x11/gtk+3/patches/patch-gtk_updateiconcache_c

    pledge("stdio rpath wpath cpath fattr")

* devel/desktop-file-utils/patches/patch-src_update-desktop-database_c

    pledge ("stdio rpath wpath cpath fattr unveil")

* textproc/mupdf/patches/patch-source_tools_pdfshow_c

    pledge("stdio rpath")
    pledge("stdio")

* archivers/pigz/patches/patch-pigz_c

    pledge("stdio rpath wpath cpath fattr chown")
    (or "stdio rpath cpath" if output is a pipe)

* archivers/xz/patches/patch-src_xz_main_c

    pledge("stdio rpath wpath cpath fattr proc")
    (or "stdio rpath proc" or "stdio proc")

* base daemons are pledged, some utilities

---

-> unveil() examples in ports/base <-
===


* devel/desktop-file-utils/patches/patch-src_update-desktop-database_c

    unveil ("/usr/local/share/locale/locale.alias", "r")
    for (i = 0; desktop_dirs[i] != NULL; i++)
      unveil (desktop_dirs[i], "rwc")
    unveil(NULL, NULL)

* misc/shared-mime-info/patches/patch-update-mime-database_c

    pledge("stdio rpath wpath cpath getpw unveil")
    unveil(mime_dir, "rwc")
    unveil(path, "r")

* devel/got

* most base daemons use `unveil()`

---

-> pledge()/unveil() within firefox <-
===


* two files per process type, `{unveil,pledge}.{main,content,gpu,socket,rdd,utility-audioDecoder}`
* defaults shipped in `/usr/local/lib/<MOZ_APP_NAME>/browser/defaults/preferences/`
* @sampled in `/etc/firefox`
* put *disable* in the first line to disable one

* files read at process startup, some env vars expanded in [ExpandUnveilPath](https://searchfox.org/mozilla-central/source/dom/ipc/ContentChild.cpp#4732)
    - *$XDG_RUNTIME_DIR*, *$XDG_CACHE_HOME* -> `~/.cache`
    - *$XDG_CONFIG_HOME* -> `~/.config`
    - *$XDG_DATA_HOME* -> `~/.local/share`
    - *~* -> `/home/<user>`

---

-> unveil() examples in firefox <-
===


    # bits of unveil.main
    $XDG_CACHE_HOME/mozilla/firefox rwc
    ~/.mozilla/firefox rwc
    /dev/dri/card0 rw
    /dev/video0 rw
    /usr/local/lib r
    /usr/local/lib/firefox rx
    /usr/local/bin/mupdf rx

---

-> when to call pledge()/unveil() in a program <-
===


* as close as possible from the mainloop
* open devices early, pass file descriptors

* in theory... practice is different
* cant easily move/'hoist' large chunks of code
* codebase is ginormous
* in the end -> initialized at the same spot as other sandboxes
* preload some libs to avoid the need to unveil() them, idea inherited from windows
* key entrypoints:
    - [StartOpenBSDSandbox](https://searchfox.org/mozilla-central/source/dom/ipc/ContentChild.cpp#4869)
    - [OpenBSDFindPledgeUnveilFilePath](https://searchfox.org/mozilla-central/source/dom/ipc/ContentChild.cpp#4660)
    - [OpenBSDPledgePromises](https://searchfox.org/mozilla-central/source/dom/ipc/ContentChild.cpp#4680)
    - [OpenBSDUnveilPaths](https://searchfox.org/mozilla-central/source/dom/ipc/ContentChild.cpp#4799)

---

-> per-process init <-
===


* `main`: [AddSandboxAnnotations](https://searchfox.org/mozilla-central/source/toolkit/xre/nsAppRunner.cpp#5237)
* `content`: [ContentChild::Init](https://searchfox.org/mozilla-central/source/dom/ipc/ContentChild.cpp#779)
* `GPU`: [GPUProcessImpl::Init](https://searchfox.org/mozilla-central/source/gfx/ipc/GPUProcessImpl.cpp#29)
* `RDD`: [RDDProcessImpl::Init](https://searchfox.org/mozilla-central/source/dom/media/ipc/RDDProcessImpl.cpp#34)
* `socket`: [SocketProcessImpl::Init](https://searchfox.org/mozilla-central/source/netwerk/ipc/SocketProcessImpl.cpp#57)
* `utility`: [UtilityProcessImpl::Init](https://searchfox.org/mozilla-central/source/ipc/glue/UtilityProcessImpl.cpp#56)
* even the [doc](https://searchfox.org/mozilla-central/source/ipc/docs/processes.rst#653) mentions OpenBSD sandboxing :)

---

-> incremental workflow to refine promises/unveiled paths <-
===


* use `ktrace` to figure out:
    - syscalls used -> pledge classes
    - files accessed -> unveil paths & access level

* repeat until it stops crashing^Wworks
* isolate access/try various things
* beware of codepaths used by underlying libs (Gtk, X...)

---

-> bugs/upstreaming <-
===


* #1457092 [Implement sandboxing on OpenBSD with pledge()](https://bugzilla.mozilla.org/show_bug.cgi?id=1457092) (63)
* #1466593 [sandboxing prevents content process to spawn a session dbus](https://bugzilla.mozilla.org/show_bug.cgi?id=1466593) (64)
* #1580268 [sandbox GPU process on OpenBSD with pledge()](https://bugzilla.mozilla.org/show_bug.cgi?id=1580268) (72)
* #1580271 [enhance sandbox on OpenBSD with unveil()](https://bugzilla.mozilla.org/show_bug.cgi?id=1580271) (69)
* #1584839 [move OpenBSD pledge() promises to files](https://bugzilla.mozilla.org/show_bug.cgi?id=1584839) (72)
* #1596546 [disable cubeb lazy dlopening on OpenBSD to fix sound when sandboxed](https://bugzilla.mozilla.org/show_bug.cgi?id=1596546) (72)
* #1623086 [lost middle and right-click in webpages in 75](https://bugzilla.mozilla.org/show_bug.cgi?id=1623086)
* #1696958 [File downloads failing with sandboxing](https://bugzilla.mozilla.org/show_bug.cgi?id=1696958)

---

-> moar bugs/upstreaming <-
===


* #1702919 [fallback to ximage for screensharing on openbsd to prevent a sandboxing violation](https://bugzilla.mozilla.org/show_bug.cgi?id=1702919)
* #1713745 [enable RDD process on OpenBSD, sandbox it with pledge/unveil](https://bugzilla.mozilla.org/show_bug.cgi?id=1713745) (91)
* #1713999 [Sandbox the socket process on OpenBSD with pledge/unveil](https://bugzilla.mozilla.org/show_bug.cgi?id=1713999)
* #1714018 [fix dconf interaction with XDG_RUNTIME_DIR on OpenBSD](https://bugzilla.mozilla.org/show_bug.cgi?id=1714018) (91)
* #1714919 [mime handler spawning with glib >= 2.64 badly interacting with OpenBSD sandboxing](https://bugzilla.mozilla.org/show_bug.cgi?id=1714919)
* #1769033 [Add OpenBSD sandboxing for Utility AudioDecoder](https://bugzilla.mozilla.org/show_bug.cgi?id=1769033) (102)
* #1770388 [Enable Utility Audio Decoder on Nightly for OpenBSD](https://bugzilla.mozilla.org/show_bug.cgi?id=1770388) (102)
* #1790419 [hoist mozilla::BinaryPath::Get before OpenBSD sandboxing](https://bugzilla.mozilla.org/show_bug.cgi?id=1790419)

---

-> runtime experience for users <-
===


* mostly transparent, no overhead
* by default, only `/tmp` & `~/Downloads` to save/load files
* need to disable pledge on main process for webrtc screen sharing ( `shmget()`)
* need to add mime handlers to `unveil.main` as explained in
  `/usr/local/share/doc/pkg-readmes/firefox`

    /usr/local/bin/xarchiver rx
    /usr/local/bin/mupdf rx
    /usr/local/bin/ristretto rx
    /usr/local/bin/soffice rx

---

-> key points <-
===


* all processes need *stdio* / *sendfd* / *recvfd* / *rpath*
    - `main` & `content` still have many things
    - `RDD` only needs *tmppath* / *unix*, */tmp rwc* -> no read access to anything else
    - `socket` only needs *inet* / *dns* (and no unveils, but for now only used for webrtc)
    - `audioDecoder` needs *tmppath*, *prot_exec*, *unix*, */tmp rwc* and read access to libs
    - `GPU` is weird, really used ?
* `unveil` quirks wrt dir creation ( `~/Downloads` )
* external handlers spawned by `main`
* could definitely be improved ... and everything should be revisited at each upgrade ?

---

-> conclusion <-
===


* `pledge()` enabled by default since firefox 60 in may 2018
* `unveil()` enabled by default since firefox 71 in december 2019
* all upstreamed !
* just works, but somewhat wide promises ?
* codebase not written with sandboxing in mind from the start makes it very hard
* things being slowly moved out to other processes (socket) ?
* a bit 'raw', eg either killed or UB/crashes - hard to debug ?
* `ktrace` is your sole friend
* `MOZ_LOG=OpenBSDSandbox:5` in the env prints unveil/pledge calls at process startup

---

-> questions ? <-
===

-> Thx to EuroBSDcon organizers ! <-
---
