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
	perlguts.pod
	perlhack.pod
	perlapi.pod
*/

#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>
#include <keywords.h> /* KEY_my, KEY_our */

#include "ppport.h"

/* Since these APIs are not public, the definitions are a little complicated */
#if PERL_REVISION == 5 && PERL_VERSION >= 10 /* >= 5.10.0 */
#	define PL_tokenbuf (PL_parser->tokenbuf)
#	define PL_in_my    (PL_parser->in_my)
#else
#	ifndef PL_tokenbuf
#		define PL_tokenbuf PL_Itokenbuf
#		define PL_in_my    PL_Iin_my
#	endif
#endif

#define SCOPE_KEY ((UV)PL_savestack_ix)

#define MY_CXT_KEY "warnings::unused::_guts" XS_VERSION /* for backward compatibility */

#define WARN_UNUSED WARN_ONCE

#define MESSAGE "Unused variable %s %s at %s line %"IVdf".\n"

typedef OP* (*check_t)(pTHX_ OP* op);

typedef struct{
	AV* vars;
	SV* scope_depth;
	U32 scope_depth_hash;
} my_cxt_t;
START_MY_CXT;

static UV
wl_fetch_scope_depth(pTHX_ pMY_CXT_ HV* tab){
	HE* he = hv_fetch_ent(tab, MY_CXT.scope_depth, FALSE, MY_CXT.scope_depth_hash);
	assert(he);

	return SvUVX(HeVAL(he));
}

static HV*
wl_push_scope(pTHX_ pMY_CXT_ UV key){
	HV* hv = newHV();

	hv_store_ent(hv, MY_CXT.scope_depth, newSVuv(key), MY_CXT.scope_depth_hash);
	av_push(MY_CXT.vars, newRV_noinc((SV*)hv));

	return hv;
}

static void
wl_flush(pTHX_ UV key){
	dMY_CXT;
	IV i = av_len(MY_CXT.vars) + 1;

	while(--i > 0){
		SV* hvref = *av_fetch(MY_CXT.vars, i, FALSE);
		HV* tab;
		HE* he;

		tab = (HV*)SvRV(hvref);

		if(wl_fetch_scope_depth(aTHX_ aMY_CXT_ tab) < key){
			break;
		}

		/* each and warn */
		hv_iterinit(tab);

		while( (he = hv_iternext(tab)) ){
			if(SvPOK(HeVAL(he))){
				Perl_warner(aTHX_ WARN_UNUSED, "%" SVf, HeVAL(he));
			}
		}

		av_pop(MY_CXT.vars);

		SvREFCNT_dec(hvref);
	}
}

static HV*
wl_fetch_tab(pTHX_ pMY_CXT_ UV key){
	HV* tab;
	UV top_depth;
	SV* top;

	top = *av_fetch(MY_CXT.vars, -1, FALSE);

	assert(SvROK(top));
	assert(SvTYPE(SvRV(top)) == SVt_PVHV);

	tab = (HV*)SvRV(top);

	top_depth = wl_fetch_scope_depth(aTHX_ aMY_CXT_ tab);

	if(top_depth < key){
		tab = wl_push_scope(aTHX_ aMY_CXT_ key);
	}
	else{ /*top_depth >= key */
		while(top_depth > key){
			HE* he;

			hv_iterinit(tab);

			while( (he = hv_iternext(tab)) ){
				if(SvPOK(HeVAL(he))){ /* skip the SCOPE_DEPTH meta data */
					Perl_warner(aTHX_ WARN_UNUSED, "%" SVf, HeVAL(he));
				}
			}

			av_pop(MY_CXT.vars);
			SvREFCNT_dec(top);

			top = *av_fetch(MY_CXT.vars, -1, FALSE);
			tab = (HV*)SvRV(top);
			top_depth = wl_fetch_scope_depth(aTHX_ aMY_CXT_ tab);
		}
	}

	assert(SvTYPE(tab) == SVt_PVHV);

	return tab;
}

static check_t old_ck_padsv  = NULL;
static check_t old_ck_padany = NULL;
static OP*
wl_ck_padany(pTHX_ OP* o){
	if(PL_in_my != KEY_our){
		dMY_CXT;
		const char* name = PL_tokenbuf;
		STRLEN namelen = strlen(name);
		HV* hv = wl_fetch_tab(aTHX_ aMY_CXT_ SCOPE_KEY);

		//warn("# SCOPE_KEY=%"UVuf, (UV)SCOPE_KEY);

		/* declaration */
		if(PL_in_my){
			SV* msg;
			if(ckWARN(WARN_UNUSED)){
				msg = Perl_newSVpvf(aTHX_
					MESSAGE,
					PL_in_my == KEY_my ? "my" : "state",
					name,
					OutCopFILE(PL_curcop), (IV)CopLINE(PL_curcop));
			}
			else{
				msg = &PL_sv_undef; /* watches but doesn't complain */
			}

			hv_store(hv, name, namelen, msg, 0);
		}
		/* use */
		else{
			SV** svp;
			I32 i = av_len(MY_CXT.vars)+1;

			/* search for the variable until it's found */
			while(!(svp = hv_fetch(hv, name, namelen, FALSE))){
				SV* href;

				assert(i > 0); /* really? */
				href = AvARRAY(MY_CXT.vars)[--i];

				hv = (HV*)SvRV(href);
			}

			/* must be found */
			assert(svp);
			if(SvOK(*svp)){
				SvREFCNT_dec(*svp);
				*svp = &PL_sv_undef;
			}

		}
	}
	return o->op_type == OP_PADSV
		? old_ck_padsv (aTHX_ o)
		: old_ck_padany(aTHX_ o);
}

/* flush on the end of subroutines */
static check_t old_ck_leavesub = NULL;
static OP*
wl_ck_leavesub(pTHX_ OP* o){
	wl_flush(aTHX_ SCOPE_KEY);

	return old_ck_leavesub(aTHX_ o);
}

/* flush on the end of evals, mainly for testing and debugging */
static check_t old_ck_leaveeval = NULL;
static OP*
wl_ck_leaveeval(pTHX_ OP* o){
	wl_flush(aTHX_ SCOPE_KEY);

	return old_ck_leaveeval(aTHX_ o);
}

MODULE = warnings::unused		PACKAGE = warnings::unused

PROTOTYPES: DISABLE

BOOT:
{
	MY_CXT_INIT;
	MY_CXT.vars = newAV();
	MY_CXT.scope_depth = newSVpvs("scope_depth");
	PERL_HASH(MY_CXT.scope_depth_hash, "scope_depth", sizeof("scope_depth")-1);
	/* the stack of varible tables */
	/* the root variable table */
	wl_push_scope(aTHX_ aMY_CXT_ (UV)1);
	/* install check hooks */
	old_ck_padany = PL_check[OP_PADANY];
	PL_check[OP_PADANY] = wl_ck_padany;
	old_ck_padsv = PL_check[OP_PADSV];
	PL_check[OP_PADSV] = wl_ck_padany;
	old_ck_leavesub = PL_check[OP_LEAVESUB];
	PL_check[OP_LEAVESUB] = wl_ck_leavesub;
	old_ck_leaveeval = PL_check[OP_LEAVEEVAL];
	PL_check[OP_LEAVEEVAL] = wl_ck_leaveeval;
}

void
END(...)
CODE:
	PERL_UNUSED_VAR(items);
	wl_flush(aTHX_ 0);

