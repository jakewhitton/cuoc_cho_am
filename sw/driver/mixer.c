#include "mixer.h"

#include <sound/control.h>
#include <sound/tlv.h>

#include "device.h"

/*===================================Volume===================================*/
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
    int addr = kcontrol->private_value;

    spin_lock_irq(&cco->mixer_lock);
    ucontrol->value.integer.value[0] = cco->mixer_volume[addr][0];
    ucontrol->value.integer.value[1] = cco->mixer_volume[addr][1];
    spin_unlock_irq(&cco->mixer_lock);

    return 0;
}

static int cco_volume_put(struct snd_kcontrol *kcontrol,
                          struct snd_ctl_elem_value *ucontrol)
{
    struct cco_device *cco = snd_kcontrol_chip(kcontrol);
    int change, addr = kcontrol->private_value;
    int left, right;

    left = ucontrol->value.integer.value[0];
    if (left < MIXER_VOLUME_LEVEL_MIN)
        left = MIXER_VOLUME_LEVEL_MIN;
    if (left > MIXER_VOLUME_LEVEL_MAX)
        left = MIXER_VOLUME_LEVEL_MAX;

    right = ucontrol->value.integer.value[1];
    if (right < MIXER_VOLUME_LEVEL_MIN)
        right = MIXER_VOLUME_LEVEL_MIN;
    if (right > MIXER_VOLUME_LEVEL_MAX)
        right = MIXER_VOLUME_LEVEL_MAX;

    spin_lock_irq(&cco->mixer_lock);
    change = cco->mixer_volume[addr][0] != left ||
             cco->mixer_volume[addr][1] != right;
    cco->mixer_volume[addr][0] = left;
    cco->mixer_volume[addr][1] = right;
    spin_unlock_irq(&cco->mixer_lock);

    return change;
}

static const DECLARE_TLV_DB_SCALE(db_scale_cco, -4500, 30, 0);

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
/*============================================================================*/


/*===================================Capsrc===================================*/
static int cco_capsrc_get(struct snd_kcontrol *kcontrol,
                          struct snd_ctl_elem_value *ucontrol)
{
    struct cco_device *cco = snd_kcontrol_chip(kcontrol);
    int addr = kcontrol->private_value;

    spin_lock_irq(&cco->mixer_lock);
    ucontrol->value.integer.value[0] = cco->capture_source[addr][0];
    ucontrol->value.integer.value[1] = cco->capture_source[addr][1];
    spin_unlock_irq(&cco->mixer_lock);

    return 0;
}

static int cco_capsrc_put(struct snd_kcontrol *kcontrol,
                          struct snd_ctl_elem_value *ucontrol)
{
    struct cco_device *cco = snd_kcontrol_chip(kcontrol);
    int change, addr = kcontrol->private_value;
    int left, right;

    left = ucontrol->value.integer.value[0] & 1;
    right = ucontrol->value.integer.value[1] & 1;

    spin_lock_irq(&cco->mixer_lock);
    change = cco->capture_source[addr][0] != left &&
             cco->capture_source[addr][1] != right;
    cco->capture_source[addr][0] = left;
    cco->capture_source[addr][1] = right;
    spin_unlock_irq(&cco->mixer_lock);

    return change;
}

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
/*============================================================================*/


/*===================================I/O Box==================================*/
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
    value->value.enumerated.item[0] = cco->iobox;

    return 0;
}

static int cco_iobox_put(struct snd_kcontrol *kcontrol,
                         struct snd_ctl_elem_value *value)
{
    struct cco_device *cco = snd_kcontrol_chip(kcontrol);
    int changed;

    if (value->value.enumerated.item[0] > 1)
        return -EINVAL;

    changed = value->value.enumerated.item[0] != cco->iobox;
    if (changed) {
        cco->iobox = value->value.enumerated.item[0];

        if (cco->iobox) {
            cco->cd_volume_ctl->vd[0].access &= ~SNDRV_CTL_ELEM_ACCESS_INACTIVE;
            cco->cd_switch_ctl->vd[0].access &= ~SNDRV_CTL_ELEM_ACCESS_INACTIVE;
        } else {
            cco->cd_volume_ctl->vd[0].access |= SNDRV_CTL_ELEM_ACCESS_INACTIVE;
            cco->cd_switch_ctl->vd[0].access |= SNDRV_CTL_ELEM_ACCESS_INACTIVE;
        }

        snd_ctl_notify(cco->card, SNDRV_CTL_EVENT_MASK_INFO,
                       &cco->cd_volume_ctl->id);
        snd_ctl_notify(cco->card, SNDRV_CTL_EVENT_MASK_INFO,
                       &cco->cd_switch_ctl->id);
    }

    return changed;
}

#define CCO_IOBOX(xname)                 \
{                                        \
    .iface = SNDRV_CTL_ELEM_IFACE_MIXER, \
    .name  = xname,                      \
    .info  = cco_iobox_info,             \
    .get   = cco_iobox_get,              \
    .put   = cco_iobox_put,              \
}
/*============================================================================*/

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

int cco_mixer_init(struct cco_device *cco)
{
    struct snd_card *card = cco->card;
    struct snd_kcontrol *kcontrol;
    unsigned int i;
    int err;

    spin_lock_init(&cco->mixer_lock);
    strcpy(card->mixername, "CCO Mixer");
    cco->iobox = 1;

    for (i = 0; i < ARRAY_SIZE(cco_controls); i++) {
		// Create new control
        kcontrol = snd_ctl_new1(&cco_controls[i], cco);

		// Add it to the card
        err = snd_ctl_add(card, kcontrol);
        if (err < 0)
            return err;

        if (!strcmp(kcontrol->id.name, "CD Volume"))
            cco->cd_volume_ctl = kcontrol;
        else if (!strcmp(kcontrol->id.name, "CD Capture Switch"))
            cco->cd_switch_ctl = kcontrol;
    }

    return 0;
}
