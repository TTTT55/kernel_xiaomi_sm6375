/* SPDX-License-Identifier: GPL-2.0 */

#include <asm/cache.h>
#include <asm/ptrace.h>
#include <asm/pgtable.h>
#include <asm/thread_info.h>

#include <asm-generic/vmlinux.lds.h>

OUTPUT_FORMAT("elf64-ia64-little")
OUTPUT_ARCH(ia64)
ENTRY(phys_start)
jiffies = jiffies_64;

PHDRS {
	code   PT_LOAD;
	percpu PT_LOAD;
	data   PT_LOAD;
	note   PT_NOTE;
	unwind 0x70000001; /* PT_IA_64_UNWIND, but ld doesn't match the name */
}

SECTIONS {
	/*
	 * unwind exit sections must be discarded before
	 * the rest of the sections get included.
	 */
	/DISCARD/ : {
		*(.IA_64.unwind.exit.text)
		*(.IA_64.unwind_info.exit.text)
		*(.comment)
		*(.note)
	}

	v = PAGE_OFFSET; /* this symbol is here to make debugging easier... */
	phys_start = _start - LOAD_OFFSET;

	code : {
	} :code
	. = KERNEL_START;

	_text = .;
	_stext = .;

	.text : AT(ADDR(.text) - LOAD_OFFSET) {
		__start_ivt_text = .;
		*(.text..ivt)
		__end_ivt_text = .;
		TEXT_TEXT
		SCHED_TEXT
		CPUIDLE_TEXT
		LOCK_TEXT
		KPROBES_TEXT
		*(.gnu.linkonce.t*)
	}

	.text2 : AT(ADDR(.text2) - LOAD_OFFSET)	{
		*(.text2)
	}

#ifdef CONFIG_SMP
	.text..lock : AT(ADDR(.text..lock) - LOAD_OFFSET) {
		*(.text..lock)
	}
#endif
	_etext = .;

	/*
	 * Read-only data
	 */
	NOTES :code :note       /* put .notes in text and mark in PT_NOTE  */
	code_continues : {
	} : code               /* switch back to regular program...  */

	EXCEPTION_TABLE(16)

	/* MCA table */
	. = ALIGN(16);
	__mca_table : AT(ADDR(__mca_table) - LOAD_OFFSET) {
		__start___mca_table = .;
		*(__mca_table)
		__stop___mca_table = .;
	}

	.data..patch.phys_stack_reg : AT(ADDR(.data..patch.phys_stack_reg) - LOAD_OFFSET) {
		__start___phys_stack_reg_patchlist = .;
		*(.data..patch.phys_stack_reg)
		__end___phys_stack_reg_patchlist = .;
	}

	/*
	 * Global data
	 */
	_data = .;

	/* Unwind info & table: */
	. = ALIGN(8);
	.IA_64.unwind_info : AT(ADDR(.IA_64.unwind_info) - LOAD_OFFSET) {
		*(.IA_64.unwind_info*)
	}
	.IA_64.unwind : AT(ADDR(.IA_64.unwind) - LOAD_OFFSET) {
		__start_unwind = .;
		*(.IA_64.unwind*)
		__end_unwind = .;
	} :code :unwind
	code_continues2 : {
	} : code

	RODATA

	.opd : AT(ADDR(.opd) - LOAD_OFFSET) {
		__start_opd = .;
		*(.opd)
		__end_opd = .;
	}

	/*
	 * Initialization code and data:
	 */
	. = ALIGN(PAGE_SIZE);
	__init_begin = .;

	INIT_TEXT_SECTION(PAGE_SIZE)
	INIT_DATA_SECTION(16)

	.data..patch.vtop : AT(ADDR(.data..patch.vtop) - LOAD_OFFSET) {
		__start___vtop_patchlist = .;
		*(.data..patch.vtop)
		__end___vtop_patchlist = .;
	}

	.data..patch.rse : AT(ADDR(.data..patch.rse) - LOAD_OFFSET) {
		__start___rse_patchlist = .;
		*(.data..patch.rse)
		__end___rse_patchlist = .;
	}

	.data..patch.mckinley_e9 : AT(ADDR(.data..patch.mckinley_e9) - LOAD_OFFSET) {
		__start___mckinley_e9_bundles = .;
		*(.data..patch.mckinley_e9)
		__end___mckinley_e9_bundles = .;
	}

#ifdef	CONFIG_SMP
	. = ALIGN(PERCPU_PAGE_SIZE);
	__cpu0_per_cpu = .;
	. = . + PERCPU_PAGE_SIZE;   /* cpu0 per-cpu space */
#endif

	. = ALIGN(PAGE_SIZE);
	__init_end = .;

	.data..page_aligned : AT(ADDR(.data..page_aligned) - LOAD_OFFSET) {
		PAGE_ALIGNED_DATA(PAGE_SIZE)
		. = ALIGN(PAGE_SIZE);
		__start_gate_section = .;
		*(.data..gate)
		__stop_gate_section = .;
	}
	/*
	 * make sure the gate page doesn't expose
	 * kernel data
	 */
	. = ALIGN(PAGE_SIZE);

	/* Per-cpu data: */
	. = ALIGN(PERCPU_PAGE_SIZE);
	PERCPU_VADDR(SMP_CACHE_BYTES, PERCPU_ADDR, :percpu)
	__phys_per_cpu_start = __per_cpu_load;
	/*
	 * ensure percpu data fits
	 * into percpu page size
	 */
	. = __phys_per_cpu_start + PERCPU_PAGE_SIZE;

	data : {
	} :data
	.data : AT(ADDR(.data) - LOAD_OFFSET) {
		_sdata  =  .;
		INIT_TASK_DATA(PAGE_SIZE)
		CACHELINE_ALIGNED_DATA(SMP_CACHE_BYTES)
		READ_MOSTLY_DATA(SMP_CACHE_BYTES)
		DATA_DATA
		*(.data1)
		*(.gnu.linkonce.d*)
		CONSTRUCTORS
	}

	BUG_TABLE

	. = ALIGN(16);	/* gp must be 16-byte aligned for exc. table */
	.got : AT(ADDR(.got) - LOAD_OFFSET) {
		*(.got.plt)
		*(.got)
	}
	__gp = ADDR(.got) + 0x200000;

	/*
	 * We want the small data sections together,
	 * so single-instruction offsets can access
	 * them all, and initialized data all before
	 * uninitialized, so we can shorten the
	 * on-disk segment size.
	 */
	.sdata : AT(ADDR(.sdata) - LOAD_OFFSET) {
		*(.sdata)
		*(.sdata1)
		*(.srdata)
	}
	_edata  =  .;

	BSS_SECTION(0, 0, 0)

	_end = .;

	code : {
	} :code

	STABS_DEBUG
	DWARF_DEBUG
	ELF_DETAILS

	/* Default discards */
	DISCARDS
}
