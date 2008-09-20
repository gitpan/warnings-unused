/* unused.xs */

/*

See also:
	op.h
	op.c
	pad.h
	pad.c
	pp.h
	pp.c
	toke.c
*/

#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>
#include <keywords.h> /* KEY_my */

#include "ppport.h"

#define WARNINGS_KEY     "unused"

#define SCOPE_KEY ((UV)PL_savestack_ix)

#define MY_CXT_KEY "warnings::unused::_guts" XS_VERSION

#ifndef PL_tokenbuf /* changed 5.10.0 */
#define PL_tokenbuf (PL_parser->tokenbuf)
#define PL_in_my    (PL_parser->in_my)
#endif


typedef struct{
	AV* vars;
} my_cxt_t;
START_MY_CXT;


static U32 warn_unused;

typedef OP* (*ck_t)(pTHX_ OP*);
typedef OP* (*pp_t)(pTHX);

static void
wl_flush(pTHX_ UV key){
	dMY_CXT;
	IV i = av_len(MY_CXT.vars) + 1;


	while(--i > 0){
		SV* hvref = *av_fetch(MY_CXT.vars, i, FALSE);
		HV* tab;
		HE* he;

		assert(SvROK(hvref));
		assert(SvTYPE(SvRV(hvref)) == SVt_PVHV);

		tab = (HV*)SvRV(hvref);

		if(key){
			SV* sv = *hv_fetchs(tab, "depth", FALSE);

			if(SvUVX(sv) < key){
				break;
			}
		}

		/* each and warn */
		hv_iterinit(tab);

		while( (he = hv_iternext(tab)) ){
			if(SvPOK(HeVAL(he))){
				Perl_warner(aTHX_ warn_unused, "%" SVf, HeVAL(he));
			}
		}

		av_pop(MY_CXT.vars);
	}
}

static HV*
wl_fetch_pad_hv(pTHX_ UV key){
	dVAR; dMY_CXT;
	HV* hv;
	SV* top_depth;
	SV* top;

	top = *av_fetch(MY_CXT.vars, -1, FALSE);

	assert(SvROK(top));
	assert(SvTYPE(SvRV(top)) == SVt_PVHV);

	hv = (HV*)SvRV(top);

	top_depth = *hv_fetchs(hv, "depth", FALSE);

	if(SvUVX(top_depth) < key){
		hv = newHV();
		hv_stores(hv, "depth", newSVuv(key));
		av_push(MY_CXT.vars, newRV_noinc((SV*)hv));
	}
	else{ /* SvUVX(top_depth) >= key */
		while(SvUVX(top_depth) > key){
			HE* he;
			av_pop(MY_CXT.vars);

			hv_iterinit(hv);

			while( (he = hv_iternext(hv)) ){
				if(SvPOK(HeVAL(he))){ /* skip the "depth" meta data */
					Perl_warner(aTHX_ warn_unused, "%" SVf, HeVAL(he));
				}
			}

			SvREFCNT_dec(top);

			top = *av_fetch(MY_CXT.vars, -1, FALSE);
			hv = (HV*)SvRV(top);
			top_depth = *hv_fetchs(hv, "depth", FALSE);
		}
	}

	assert(SvTYPE(hv) == SVt_PVHV);

	return hv;
}


static ck_t old_ck_padany = NULL;
static OP*
wl_ck_padany(pTHX_ OP* o){
	if(PL_in_my != KEY_our && ckWARN(warn_unused)){
		const char* name = PL_tokenbuf;
		STRLEN namelen = strlen(name);
		HV* hv = wl_fetch_pad_hv(aTHX_ SCOPE_KEY);

		//warn("# SCOPE_KEY=%"UVuf, (UV)SCOPE_KEY);

		/* declaration */
		if(PL_in_my){
			SV* msg = Perl_newSVpvf(aTHX_
				"Unused variable %s %s at %s line %"IVdf".\n",
				PL_in_my == KEY_my ? "my" : "state",
				name,
				OutCopFILE(PL_curcop), (IV)CopLINE(PL_curcop));

			hv_store(hv, name, namelen, msg, 0);
		}
		/* use */
		else{
			SV* sv;
			dMY_CXT;
			I32 i = -1;

			/* search for the variable until it's found */
			while(!(sv = hv_delete(hv, name, namelen, 0))){
				SV** svp = av_fetch(MY_CXT.vars, --i, FALSE);

				if(!svp) break;

				assert(SvROK(*svp));
				assert(SvTYPE(SvRV(*svp)) == SVt_PVHV);
				hv = (HV*)SvRV(*svp);
			}

		}

	}
	return old_ck_padany(aTHX_ o);
}

static ck_t old_ck_leavesub = NULL;
static OP*
wl_ck_leavesub(pTHX_ OP* o){
	wl_flush(aTHX_ SCOPE_KEY);

	return old_ck_leavesub(aTHX_ o);
}

MODULE = warnings::unused		PACKAGE = warnings::unused

PROTOTYPES: DISABLE

BOOT:
{
	HV* tab;
	/* fetch the offset from %warnings::Offsets */
	SV* offset  = *hv_fetchs(get_hv("warnings::Offsets", TRUE), WARNINGS_KEY, TRUE);
	MY_CXT_INIT;
	warn_unused = (U32)(SvUV(offset) / 2);
	/* install check hooks */
	old_ck_padany = PL_check[OP_PADANY];
	PL_check[OP_PADANY] = wl_ck_padany;
	old_ck_leavesub = PL_check[OP_LEAVESUB];
	PL_check[OP_LEAVESUB] = wl_ck_leavesub;
	/* the stack of varible tables */
	MY_CXT.vars = newAV();
	/* the root variable table */
	tab = newHV();
	hv_stores(tab, "depth", newSVuv((UV)1));
	av_push(MY_CXT.vars, newRV_noinc((SV*)tab));
}

void
END(...)
ALIAS:
	flush = 1
CODE:
	PERL_UNUSED_VAR(items);
	PERL_UNUSED_VAR(ix);
	wl_flush(aTHX_ 0);

