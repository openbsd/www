@title=Memory allocators in modern Operating Systems
@foreground=#171319
@background=#ffffff

---
@type=title
<Ariane van der Steldt>
ariane@openbsd.org
---
@type=intro
<Content>
pmemrange: the physical memory allocator
vmmap: the virtual memory allocator
64-bit and jit
---
@type=title
<Physical memory>
!pmemrange - physical memory!
---
@type=normal
<Before pmemrange>
Physical memory was a list of pages.
[img src=physmem_tailq.png align=center size=100%]

This caused high fragmentation.
[img src=physmem_old_bootup.png align=center size=100%]
Fragmentation is bad for devices.
!pmemrange - physical memory!
---
@type=normal
<Before pmemrange - it gets worse>
ISA and PCI devices could become starved.
[img src=physmem_old_isapci.png align=center size=100%]

ISA and PCI device can no longer make progress.

* Devices /need memory/ to progress
* Programs /block/ on data access
* System becomes *unresponsive*
!pmemrange - physical memory!
---
@type=normal
<Pmemrange>
A new physical memory allocator:
*P*hysical
*Mem*ory
*range*

* must keep device memory available
* must reduce fragmentation
* may not regress: don't be slower!
!pmemrange - physical memory!
---
@type=normal
<Memory ranges>
[img src=pmemrange_ranges.png align=center size=100%]
!pmemrange - physical memory!
---
@type=normal
<Memory allocation>
[img src=pmemrange_bintree.png align=center size=100%]
* Large fragments /grow/
* Small fragments /shrink and vanish/
* Faster than best fit *O(1) common case*

*Pmemrange turned out to be faster than the original code!*
!pmemrange - physical memory!
---
@type=title
<VMmap>
!VMmap - virtual memory!
---
@type=normal
<VM map>
VMmap: mapping Virtual Memory
- keeps track of what is allocated where
- manages virtual memory of kernel and userspace
- performs allocation
!VMmap - virtual memory!
---
@type=normal
<Original VMmap>
* Introduced around 1999
* First fit allocator
* Code hasn't really change since then
Address Space Layout Randomization tacked on without adapting the underlying algorithm.
[img src=vmmap_layout.png align=center size=100%]
!VMmap - virtual memory!
---
@type=normal
<Original address selection>
* Randomly pick an address.
* Check if that address is free /(do you feel lucky?)/
* Otherwise, linear search forward.

Problems:
* Complexity /grows quadratic/ with memory use
	- double the memory, double number of entries to walk
	- increase the memory, reduce the chance of getting lucky
* Forward-only search may yield /false negative/
	- select high random address, skipping all that free space below
!VMmap - virtual memory!
---
@type=normal
<First replacement>
Best-fit allocator.
* Select close to the best allocation (random number).
* Select random address within that allocation.

The good:
* No false negatives
* O(log n) instead of O(n**2)
!VMmap - virtual memory!
---
@type=normal
<First replacement failed>
The bad:
* Some architectures stopped working altogether
* Introduced new bugs
The ugly:
* Webbrowsing was impossible
* Java and mono ceased to function
* Touch the code and an architecture dies
* Randomization was too predictable: *not random*
!VMmap - virtual memory!
---
@type=normal
<How did this break random?>
Investigating what went wrong.
* Placement position of each allocation was random.
* Memory layout was not very random at all.
* An attacker does not need to target specific memory, he just attacks everything and sees what sticks.
Implementation bugs made this worse.
Randomization did add gaps, but was too predictable in which memory was used.
!VMmap - virtual memory!
---
@type=normal
<Browsers, java & mono breakage>
They all use JIT (Just In Time) compilation.
- To make byte-code or javascript fast
- They all use PIC (Position Independant Code)
!VMmap - virtual memory!
---
@type=normal
<PIC - Position Independant Code>
[img src=jit_nearptr.png align=center size=100%]
!VMmap - virtual memory!
---
@type=normal
<PIC - Position Independant Code>
PIC makes code agnostic to position.
Offset is a 32-bit value.
* Sufficient for libraries
	- No 4 GB libraries
* JITs allocate both parts.
	- 64-bit pointer clipped
!VMmap - virtual memory!
---
@type=normal
<JIT - pointer clipping>
^Aw, Snap!^
[img src=jit_ptrclip.png align=center size=100%]
!VMmap - virtual memory!
---
@type=normal
<JIT - workarounds>
* Linux: mmap MAP_32BIT
	- it's in API, can never be removed
* Chrome: allocate 2 GB up front
	- use own memory allocator in there
	- Hello predictable attack surface
!VMmap - virtual memory!
---
@type=normal
<Smart and dumb software>
* sizeof(void*) != sizeof(int)
* sizeof(array) > MAXINT
* sizeof(ptrdiff_t) != sizeof(int)
Good software is boring:
* use /size_t/ for sizes
* always /check for clipping/ when translating to another type
!VMmap - virtual memory!
---
@type=normal
<VMmap additional requirements>
* must not add extra options to mmap
* isolate userland and kernel space fixes
	- don't want to break architectures
	- kernel memory is very special
* must not break browsers
	- mmap hint requirements allow ports to rig browser workarounds
* must allow easy switching of algorithms
	- small commit/backout diffs
!VMmap - virtual memory!
---
@type=normal
<Split mapping and allocation>
[img src=vmmap_architecture.png align=center size=100%]
* Address selectors decide where to allocate
	- read access on map
	- multiple implementations
* Map keeps track of what is allocated where
	- informs selectors of modifications
* VMmap combines the two together
!VMmap - virtual memory!
---
@type=normal
<vm_map - allocation in VMmap>
[img src=vmmap_alloc.png align=center size=100%]
!VMmap - virtual memory!
---
@type=normal
<vm_unmap - unmapping in VMmap>
[img src=vmmap_free.png align=center size=100%]
!VMmap - virtual memory!
---
@type=normal
<Compatibility for JIT>
>mmap(addr, size, ...)<
Posix says: "A non-zero value of /addr/ is taken to be a suggestion of a process address near which the mapping should be placed"
* WTF? What does *near* mean?
	- in the same machine is pretty near...
	- we define near as max 1 GB away (sufficiently near for PIC)
* First 4 GB is special: we only allocate there if your hint &le; 4 GB
Allows us to fix browsers.
Functionality implemented in hint selector.
!VMmap - virtual memory!
---
@type=normal
<Better random algorithm>
* Random placement of memory
	- make it hard to guess a good position
* Random gaps between memory
	- don't make walking the memory easy
Introducing pivot allocator
!VMmap - virtual memory!
---
@type=normal
<Pivot algorithm>
16 active pivots
[img src=vmmap_pivot.png align=center size=100%]
* Pivots leave gaps between allocations
* Pivots expire every 1024 allocations
* Pivots walk either forward or backwards
Common case: O(1)
Pivot creation: O(log n)
Low fragmentation, hard to predict
!VMmap - virtual memory!
---
@type=normal
<Wrapping it up>
* Devices and software are pretty similar
	- both have assumptions on pointers
	- devices often can't help it: PCI spec is 32-bit
[img src=cray.jpg align=right size=100%]
* Software hasn't really improved in 40 years
	- first 64-bit machine: Cray-1 (1976)
	- the world isn't only i386
	- software still trips on 64-bits
	- designs are copied without understanding them (why else would JITs forget to cope with 64-bit distance?)
* ASLR (Address Space Layout Randomization) is difficult
	- our initial implementation got it right, we were lucky
!Memory allocators in modern Operating Systems!
