#include "mixer.h"

#include <sound/control.h>
#include <sound/tlv.h>

#include "device.h"

#define DUMMY_VOLUME(xname, xindex, addr) \
{ .iface = SNDRV_CTL_ELEM_IFACE_MIXER, \
  .access = SNDRV_CTL_ELEM_ACCESS_READWRITE | SNDRV_CTL_ELEM_ACCESS_TLV_READ, \
  .name = xname, .index = xindex, \
  .info = snd_dummy_volume_info, \
  .get = snd_dummy_volume_get, .put = snd_dummy_volume_put, \
  .private_value = addr, \
  .tlv = { .p = db_scale_dummy } }

static int snd_dummy_volume_info(struct snd_kcontrol *kcontrol,
                 struct snd_ctl_elem_info *uinfo)
{
    uinfo->type = SNDRV_CTL_ELEM_TYPE_INTEGER;
    uinfo->count = 2;
    uinfo->value.integer.min = mixer_volume_level_min;
    uinfo->value.integer.max = mixer_volume_level_max;
    return 0;
}

static int snd_dummy_volume_get(struct snd_kcontrol *kcontrol,
                struct snd_ctl_elem_value *ucontrol)
{
    struct snd_dummy *dummy = snd_kcontrol_chip(kcontrol);
    int addr = kcontrol->private_value;

    spin_lock_irq(&dummy->mixer_lock);
    ucontrol->value.integer.value[0] = dummy->mixer_volume[addr][0];
    ucontrol->value.integer.value[1] = dummy->mixer_volume[addr][1];
    spin_unlock_irq(&dummy->mixer_lock);
    return 0;
}

static int snd_dummy_volume_put(struct snd_kcontrol *kcontrol,
                struct snd_ctl_elem_value *ucontrol)
{
    struct snd_dummy *dummy = snd_kcontrol_chip(kcontrol);
    int change, addr = kcontrol->private_value;
    int left, right;

    left = ucontrol->value.integer.value[0];
    if (left < mixer_volume_level_min)
        left = mixer_volume_level_min;
    if (left > mixer_volume_level_max)
        left = mixer_volume_level_max;
    right = ucontrol->value.integer.value[1];
    if (right < mixer_volume_level_min)
        right = mixer_volume_level_min;
    if (right > mixer_volume_level_max)
        right = mixer_volume_level_max;
    spin_lock_irq(&dummy->mixer_lock);
    change = dummy->mixer_volume[addr][0] != left ||
             dummy->mixer_volume[addr][1] != right;
    dummy->mixer_volume[addr][0] = left;
    dummy->mixer_volume[addr][1] = right;
    spin_unlock_irq(&dummy->mixer_lock);
    return change;
}

static const DECLARE_TLV_DB_SCALE(db_scale_dummy, -4500, 30, 0);

#define DUMMY_CAPSRC(xname, xindex, addr) \
{ .iface = SNDRV_CTL_ELEM_IFACE_MIXER, .name = xname, .index = xindex, \
  .info = snd_dummy_capsrc_info, \
  .get = snd_dummy_capsrc_get, .put = snd_dummy_capsrc_put, \
  .private_value = addr }

#define snd_dummy_capsrc_info    snd_ctl_boolean_stereo_info

static int snd_dummy_capsrc_get(struct snd_kcontrol *kcontrol,
                struct snd_ctl_elem_value *ucontrol)
{
    struct snd_dummy *dummy = snd_kcontrol_chip(kcontrol);
    int addr = kcontrol->private_value;

    spin_lock_irq(&dummy->mixer_lock);
    ucontrol->value.integer.value[0] = dummy->capture_source[addr][0];
    ucontrol->value.integer.value[1] = dummy->capture_source[addr][1];
    spin_unlock_irq(&dummy->mixer_lock);
    return 0;
}

static int snd_dummy_capsrc_put(struct snd_kcontrol *kcontrol, struct snd_ctl_elem_value *ucontrol)
{
    struct snd_dummy *dummy = snd_kcontrol_chip(kcontrol);
    int change, addr = kcontrol->private_value;
    int left, right;

    left = ucontrol->value.integer.value[0] & 1;
    right = ucontrol->value.integer.value[1] & 1;
    spin_lock_irq(&dummy->mixer_lock);
    change = dummy->capture_source[addr][0] != left &&
             dummy->capture_source[addr][1] != right;
    dummy->capture_source[addr][0] = left;
    dummy->capture_source[addr][1] = right;
    spin_unlock_irq(&dummy->mixer_lock);
    return change;
}

static int snd_dummy_iobox_info(struct snd_kcontrol *kcontrol,
                struct snd_ctl_elem_info *info)
{
    static const char *const names[] = { "None", "CD Player" };

    return snd_ctl_enum_info(info, 1, 2, names);
}

static int snd_dummy_iobox_get(struct snd_kcontrol *kcontrol,
                   struct snd_ctl_elem_value *value)
{
    struct snd_dummy *dummy = snd_kcontrol_chip(kcontrol);

    value->value.enumerated.item[0] = dummy->iobox;
    return 0;
}

static int snd_dummy_iobox_put(struct snd_kcontrol *kcontrol,
                   struct snd_ctl_elem_value *value)
{
    struct snd_dummy *dummy = snd_kcontrol_chip(kcontrol);
    int changed;

    if (value->value.enumerated.item[0] > 1)
        return -EINVAL;

    changed = value->value.enumerated.item[0] != dummy->iobox;
    if (changed) {
        dummy->iobox = value->value.enumerated.item[0];

        if (dummy->iobox) {
            dummy->cd_volume_ctl->vd[0].access &=
                ~SNDRV_CTL_ELEM_ACCESS_INACTIVE;
            dummy->cd_switch_ctl->vd[0].access &=
                ~SNDRV_CTL_ELEM_ACCESS_INACTIVE;
        } else {
            dummy->cd_volume_ctl->vd[0].access |=
                SNDRV_CTL_ELEM_ACCESS_INACTIVE;
            dummy->cd_switch_ctl->vd[0].access |=
                SNDRV_CTL_ELEM_ACCESS_INACTIVE;
        }

        snd_ctl_notify(dummy->card, SNDRV_CTL_EVENT_MASK_INFO,
                   &dummy->cd_volume_ctl->id);
        snd_ctl_notify(dummy->card, SNDRV_CTL_EVENT_MASK_INFO,
                   &dummy->cd_switch_ctl->id);
    }

    return changed;
}

static const struct snd_kcontrol_new snd_dummy_controls[] = {
DUMMY_VOLUME("Master Volume", 0, MIXER_ADDR_MASTER),
DUMMY_CAPSRC("Master Capture Switch", 0, MIXER_ADDR_MASTER),
DUMMY_VOLUME("Synth Volume", 0, MIXER_ADDR_SYNTH),
DUMMY_CAPSRC("Synth Capture Switch", 0, MIXER_ADDR_SYNTH),
DUMMY_VOLUME("Line Volume", 0, MIXER_ADDR_LINE),
DUMMY_CAPSRC("Line Capture Switch", 0, MIXER_ADDR_LINE),
DUMMY_VOLUME("Mic Volume", 0, MIXER_ADDR_MIC),
DUMMY_CAPSRC("Mic Capture Switch", 0, MIXER_ADDR_MIC),
DUMMY_VOLUME("CD Volume", 0, MIXER_ADDR_CD),
DUMMY_CAPSRC("CD Capture Switch", 0, MIXER_ADDR_CD),
{
    .iface = SNDRV_CTL_ELEM_IFACE_MIXER,
    .name  = "External I/O Box",
    .info  = snd_dummy_iobox_info,
    .get   = snd_dummy_iobox_get,
    .put   = snd_dummy_iobox_put,
},
};

int snd_card_dummy_new_mixer(struct snd_dummy *dummy)
{
    struct snd_card *card = dummy->card;
    struct snd_kcontrol *kcontrol;
    unsigned int idx;
    int err;

    spin_lock_init(&dummy->mixer_lock);
    strcpy(card->mixername, "Dummy Mixer");
    dummy->iobox = 1;

    for (idx = 0; idx < ARRAY_SIZE(snd_dummy_controls); idx++) {
        kcontrol = snd_ctl_new1(&snd_dummy_controls[idx], dummy);
        err = snd_ctl_add(card, kcontrol);
        if (err < 0)
            return err;
        if (!strcmp(kcontrol->id.name, "CD Volume"))
            dummy->cd_volume_ctl = kcontrol;
        else if (!strcmp(kcontrol->id.name, "CD Capture Switch"))
            dummy->cd_switch_ctl = kcontrol;

    }
    return 0;
}
