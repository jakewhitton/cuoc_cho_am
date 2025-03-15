/* include/aconfig.h.  Generated from aconfig.h.in by configure.  */
/* include/aconfig.h.in.  Generated from configure.ac by autoheader.  */

/* directory containing ALSA topology pre-process plugins */
#define ALSA_TOPOLOGY_PLUGIN_DIR "/usr/lib/alsa-topology"

/* directory containing alsa configuration */
#define DATADIR "/usr/share/alsa"

/* Define to 1 if translation of program messages to the user's native
   language is requested. */
/* #undef ENABLE_NLS */

/* Define if curses-based programs can show translated messages. */
/* #undef ENABLE_NLS_IN_CURSES */

/* Define to 1 if you have the <alsa/mixer.h> header file. */
#define HAVE_ALSA_MIXER_H 1

/* Define to 1 if you have the <alsa/pcm.h> header file. */
#define HAVE_ALSA_PCM_H 1

/* Define to 1 if you have the <alsa/rawmidi.h> header file. */
#define HAVE_ALSA_RAWMIDI_H 1

/* Define to 1 if you have the <alsa/seq.h> header file. */
#define HAVE_ALSA_SEQ_H 1

/* Define to 1 if you have the <alsa/topology.h> header file. */
#define HAVE_ALSA_TOPOLOGY_H 1

/* Define to 1 if you have the <alsa/use-case.h> header file. */
#define HAVE_ALSA_USE_CASE_H 1

/* Define to 1 if you have the Mac OS X function
   CFLocaleCopyPreferredLanguages in the CoreFoundation framework. */
/* #undef HAVE_CFLOCALECOPYPREFERREDLANGUAGES */

/* Define to 1 if you have the Mac OS X function CFPreferencesCopyAppValue in
   the CoreFoundation framework. */
/* #undef HAVE_CFPREFERENCESCOPYAPPVALUE */

/* Have clock gettime */
#define HAVE_CLOCK_GETTIME 1

/* Have curses set_escdelay */
#define HAVE_CURSES_ESCDELAY 1

/* Define if the GNU dcgettext() function is already present or preinstalled.
   */
/* #undef HAVE_DCGETTEXT */

/* Define to 1 if you have the <dlfcn.h> header file. */
#define HAVE_DLFCN_H 1

/* Define to 1 if you have the <form.h> header file. */
#define HAVE_FORM_H 1

/* Define if the GNU gettext() function is already present or preinstalled. */
/* #undef HAVE_GETTEXT */

/* Define if you have the iconv() function and it works. */
/* #undef HAVE_ICONV */

/* Define to 1 if you have the <inttypes.h> header file. */
#define HAVE_INTTYPES_H 1

/* Define to 1 if you have the 'asound' library (-lasound). */
#define HAVE_LIBASOUND 1

/* Define to 1 if you have the 'atopology' library (-latopology). */
#define HAVE_LIBATOPOLOGY 1

/* Define to 1 if you have the 'fftw3f' library (-lfftw3f). */
/* #undef HAVE_LIBFFTW3F */

/* Define to 1 if you have the 'm' library (-lm). */
/* #undef HAVE_LIBM */

/* Define to 1 if you have the 'pthread' library (-lpthread). */
/* #undef HAVE_LIBPTHREAD */

/* Have librt */
#define HAVE_LIBRT 1

/* Define to 1 if you have the 'tinyalsa' library (-ltinyalsa). */
/* #undef HAVE_LIBTINYALSA */

/* Define to 1 if you have the <malloc.h> header file. */
#define HAVE_MALLOC_H 1

/* Define if Linux kernel supports memfd_create system call */
#define HAVE_MEMFD_CREATE 1

/* Define to 1 if you have the <menu.h> header file. */
#define HAVE_MENU_H 1

/* Define to 1 if you have the <panel.h> header file. */
#define HAVE_PANEL_H 1

/* Define to 1 if you have the <samplerate.h> header file. */
/* #undef HAVE_SAMPLERATE_H */

/* alsa-lib supports snd_seq_client_info_get_card */
#define HAVE_SEQ_CLIENT_INFO_GET_CARD 1

/* alsa-lib supports snd_seq_client_info_get_midi_version */
#define HAVE_SEQ_CLIENT_INFO_GET_MIDI_VERSION 1

/* alsa-lib supports snd_seq_client_info_get_pid */
#define HAVE_SEQ_CLIENT_INFO_GET_PID 1

/* Define to 1 if you have the <stdint.h> header file. */
#define HAVE_STDINT_H 1

/* Define to 1 if you have the <stdio.h> header file. */
#define HAVE_STDIO_H 1

/* Define to 1 if you have the <stdlib.h> header file. */
#define HAVE_STDLIB_H 1

/* Define to 1 if you have the <strings.h> header file. */
#define HAVE_STRINGS_H 1

/* Define to 1 if you have the <string.h> header file. */
#define HAVE_STRING_H 1

/* Define to 1 if you have the <sys/stat.h> header file. */
#define HAVE_SYS_STAT_H 1

/* Define to 1 if you have the <sys/time.h> header file. */
#define HAVE_SYS_TIME_H 1

/* Define to 1 if you have the <sys/types.h> header file. */
#define HAVE_SYS_TYPES_H 1

/* Define to 1 if you have the <unistd.h> header file. */
#define HAVE_UNISTD_H 1

/* Define to the sub-directory where libtool stores uninstalled libraries. */
#define LT_OBJDIR ".libs/"

/* Name of package */
#define PACKAGE "alsa-utils"

/* Define to the address where bug reports for this package should be sent. */
#define PACKAGE_BUGREPORT ""

/* Define to the full name of this package. */
#define PACKAGE_NAME "alsa-utils"

/* Define to the full name and version of this package. */
#define PACKAGE_STRING "alsa-utils 1.2.11"

/* Define to the one symbol short name of this package. */
#define PACKAGE_TARNAME "alsa-utils"

/* Define to the home page for this package. */
#define PACKAGE_URL ""

/* Define to the version of this package. */
#define PACKAGE_VERSION "1.2.11"

/* directory containing sample data */
#define SOUNDSDIR "/usr/share/sounds/alsa"

/* Define to 1 if all of the C89 standard headers exist (not just the ones
   required in a freestanding environment). This macro is provided for
   backward compatibility; new code need not use it. */
#define STDC_HEADERS 1

/* Define to 1 if you can safely include both <sys/time.h> and <time.h>. This
   macro is obsolete. */
#define TIME_WITH_SYS_TIME 1

/* ALSA util version */
#define VERSION "1.2.11"

/* Define if FFADO library is available */
/* #undef WITH_FFADO */

/* Number of bits in a file offset, on hosts where this is settable. */
/* #undef _FILE_OFFSET_BITS */

/* Define to 1 on platforms where this makes off_t a 64-bit type. */
/* #undef _LARGE_FILES */

/* Number of bits in time_t, on hosts where this is settable. */
/* #undef _TIME_BITS */

/* Define to 1 on platforms where this makes time_t a 64-bit type. */
/* #undef __MINGW_USE_VC2005_COMPAT */

/* Define to empty if 'const' does not conform to ANSI C. */
/* #undef const */

/* Define to '__inline__' or '__inline' if that's what the C compiler
   calls it, or to nothing if 'inline' is not supported under any name.  */
#ifndef __cplusplus
/* #undef inline */
#endif
