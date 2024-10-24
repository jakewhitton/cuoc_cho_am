#include "mixer.h"

#include <sound/tlv.h>

#include "device.h"
#include "log.h"

/*===============================Initialization===============================*/
// Full definition is in "Control definitions" section
static const struct snd_kcontrol_new cco_controls[];
static const int num_controls;

int cco_mixer_init(struct cco_device *cco)
{
    int err;
    struct cco_mixer *m = &cco->mixer;

    spin_lock_init(&m->lock);
    strcpy(cco->card->mixername, "CCO Mixer");
    m->iobox = 1;

    for (int i = 0; i < num_controls; i++) {
        // Create new control
        struct snd_kcontrol *kcontrol = snd_ctl_new1(&cco_controls[i], cco);

        // Add it to the card
        err = snd_ctl_add(cco->card, kcontrol);
        if (err < 0) {
            printk(KERN_ERR "cco: snd_ctl_add() failed\n");
            goto exit_error;
        }

        if (!strcmp(kcontrol->id.name, "CD Volume"))
            m->cd_volume_ctl = kcontrol;
        else if (!strcmp(kcontrol->id.name, "CD Capture Switch"))
            m->cd_switch_ctl = kcontrol;
    }

    return 0;

exit_error:
    CCO_LOG_FUNCTION_FAILURE(err);
    return err;
}
/*============================================================================*/


/*===================================Volume===================================*/
#define CCO_VOLUME(xname, xindex, addr)                  \
{                                                        \
    .iface         = SNDRV_CTL_ELEM_IFACE_MIXER,         \
    .name          = xname,                              \
    .index         = xindex,                             \
    .access        = ( SNDRV_CTL_ELEM_ACCESS_READWRITE   \
                     | SNDRV_CTL_ELEM_ACCESS_TLV_READ ), \
    .info          = cco_volume_info,                    \
    .get           = cco_volume_get,                     \
    .put           = cco_volume_put,                     \
    .tlv           = {                                   \
        .p = db_scale_cco                                \
    },                                                   \
    .private_value = addr,                               \
}

static int cco_volume_info(struct snd_kcontrol *kcontrol,
                           struct snd_ctl_elem_info *uinfo)
{
    uinfo->type = SNDRV_CTL_ELEM_TYPE_INTEGER;
    uinfo->count = 2;
    uinfo->value.integer.min = MIXER_VOLUME_LEVEL_MIN;
    uinfo->value.integer.max = MIXER_VOLUME_LEVEL_MIN;

    return 0;
}

static int cco_volume_get(struct snd_kcontrol *kcontrol,
                          struct snd_ctl_elem_value *ucontrol)
{
    struct cco_device *cco = snd_kcontrol_chip(kcontrol);
    struct cco_mixer *m = &cco->mixer;
    int addr = kcontrol->private_value;

    spin_lock_irq(&m->lock);
    ucontrol->value.integer.value[0] = m->volume[addr][0];
    ucontrol->value.integer.value[1] = m->volume[addr][1];
    spin_unlock_irq(&m->lock);

    return 0;
}

static int cco_volume_put(struct snd_kcontrol *kcontrol,
                          struct snd_ctl_elem_value *ucontrol)
{
    struct cco_device *cco = snd_kcontrol_chip(kcontrol);
    struct cco_mixer *m = &cco->mixer;
    const int addr = kcontrol->private_value;

    int left = ucontrol->value.integer.value[0];
    if (left < MIXER_VOLUME_LEVEL_MIN)
        left = MIXER_VOLUME_LEVEL_MIN;
    if (left > MIXER_VOLUME_LEVEL_MAX)
        left = MIXER_VOLUME_LEVEL_MAX;

    int right = ucontrol->value.integer.value[1];
    if (right < MIXER_VOLUME_LEVEL_MIN)
        right = MIXER_VOLUME_LEVEL_MIN;
    if (right > MIXER_VOLUME_LEVEL_MAX)
        right = MIXER_VOLUME_LEVEL_MAX;

    int change;
    spin_lock_irq(&m->lock);
    change = m->volume[addr][0] != left ||
             m->volume[addr][1] != right;
    m->volume[addr][0] = left;
    m->volume[addr][1] = right;
    spin_unlock_irq(&m->lock);

    return change;
}

static const DECLARE_TLV_DB_SCALE(db_scale_cco, -4500, 30, 0);
/*============================================================================*/


/*===================================Capsrc===================================*/
#define CCO_CAPSRC(xname, xindex, addr)           \
{                                                 \
    .iface         = SNDRV_CTL_ELEM_IFACE_MIXER,  \
    .name          = xname,                       \
    .index         = xindex,                      \
    .info          = snd_ctl_boolean_stereo_info, \
    .get           = cco_capsrc_get,              \
    .put           = cco_capsrc_put,              \
    .private_value = addr,                        \
}

static int cco_capsrc_get(struct snd_kcontrol *kcontrol,
                          struct snd_ctl_elem_value *ucontrol)
{
    struct cco_device *cco = snd_kcontrol_chip(kcontrol);
    struct cco_mixer *m = &cco->mixer;
    const int addr = kcontrol->private_value;

    spin_lock_irq(&m->lock);
    ucontrol->value.integer.value[0] = m->capture_source[addr][0];
    ucontrol->value.integer.value[1] = m->capture_source[addr][1];
    spin_unlock_irq(&m->lock);

    return 0;
}

static int cco_capsrc_put(struct snd_kcontrol *kcontrol,
                          struct snd_ctl_elem_value *ucontrol)
{
    struct cco_device *cco = snd_kcontrol_chip(kcontrol);
    struct cco_mixer *m = &cco->mixer;
    const int addr = kcontrol->private_value;

    const int left = ucontrol->value.integer.value[0] & 1;
    const int right = ucontrol->value.integer.value[1] & 1;

    int change;
    spin_lock_irq(&m->lock);
    change = m->capture_source[addr][0] != left &&
             m->capture_source[addr][1] != right;
    m->capture_source[addr][0] = left;
    m->capture_source[addr][1] = right;
    spin_unlock_irq(&m->lock);

    return change;
}
/*============================================================================*/


/*===================================I/O Box==================================*/
#define CCO_IOBOX(xname)                 \
{                                        \
    .iface = SNDRV_CTL_ELEM_IFACE_MIXER, \
    .name  = xname,                      \
    .info  = cco_iobox_info,             \
    .get   = cco_iobox_get,              \
    .put   = cco_iobox_put,              \
}

static int cco_iobox_info(struct snd_kcontrol *kcontrol,
                          struct snd_ctl_elem_info *info)
{
    static const char *const names[] = { "None", "CD Player" };

    return snd_ctl_enum_info(info, 1, 2, names);
}

static int cco_iobox_get(struct snd_kcontrol *kcontrol,
                         struct snd_ctl_elem_value *value)
{
    struct cco_device *cco = snd_kcontrol_chip(kcontrol);
    struct cco_mixer *m = &cco->mixer;
    value->value.enumerated.item[0] = m->iobox;

    return 0;
}

static int cco_iobox_put(struct snd_kcontrol *kcontrol,
                         struct snd_ctl_elem_value *value)
{
    struct cco_device *cco = snd_kcontrol_chip(kcontrol);
    struct cco_mixer *m = &cco->mixer;

    if (value->value.enumerated.item[0] > 1)
        return -EINVAL;

    const int changed = value->value.enumerated.item[0] != m->iobox;
    if (changed) {
        m->iobox = value->value.enumerated.item[0];

        if (m->iobox) {
            m->cd_volume_ctl->vd[0].access &= ~SNDRV_CTL_ELEM_ACCESS_INACTIVE;
            m->cd_switch_ctl->vd[0].access &= ~SNDRV_CTL_ELEM_ACCESS_INACTIVE;
        } else {
            m->cd_volume_ctl->vd[0].access |= SNDRV_CTL_ELEM_ACCESS_INACTIVE;
            m->cd_switch_ctl->vd[0].access |= SNDRV_CTL_ELEM_ACCESS_INACTIVE;
        }

        snd_ctl_notify(cco->card, SNDRV_CTL_EVENT_MASK_INFO,
                       &m->cd_volume_ctl->id);
        snd_ctl_notify(cco->card, SNDRV_CTL_EVENT_MASK_INFO,
                       &m->cd_switch_ctl->id);
    }

    return changed;
}
/*============================================================================*/


/*=============================Control definitions============================*/
static const struct snd_kcontrol_new cco_controls[] = {
    CCO_VOLUME("Master Volume",         0, MIXER_ADDR_MASTER),
    CCO_CAPSRC("Master Capture Switch", 0, MIXER_ADDR_MASTER),
    CCO_VOLUME("Synth Volume",          0, MIXER_ADDR_SYNTH),
    CCO_CAPSRC("Synth Capture Switch",  0, MIXER_ADDR_SYNTH),
    CCO_VOLUME("Line Volume",           0, MIXER_ADDR_LINE),
    CCO_CAPSRC("Line Capture Switch",   0, MIXER_ADDR_LINE),
    CCO_VOLUME("Mic Volume",            0, MIXER_ADDR_MIC),
    CCO_CAPSRC("Mic Capture Switch",    0, MIXER_ADDR_MIC),
    CCO_VOLUME("CD Volume",             0, MIXER_ADDR_CD),
    CCO_CAPSRC("CD Capture Switch",     0, MIXER_ADDR_CD),
    CCO_IOBOX("External I/O Box"),
};
static const int num_controls = ARRAY_SIZE(cco_controls);
/*============================================================================*/
