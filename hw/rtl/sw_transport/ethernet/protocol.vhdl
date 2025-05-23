library work;
    use work.ethernet.all;

library util;
    use util.audio.all;
    use util.types.all;

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package protocol is

    -----------------------------------Header-----------------------------------
    subtype Magic_t is std_logic_vector(0 to (4 * BITS_PER_BYTE) - 1);
    constant CCO_MAGIC : Magic_t := X"83F8DDEF";

    subtype GenerationId_t is unsigned(0 to BITS_PER_BYTE - 1);
    constant MAX_GENERATION_ID : natural := 255;

    subtype MsgType_t is std_logic_vector(0 to BITS_PER_BYTE - 1);
    attribute msg_type : MsgType_t;

    type Msg_t is record
        magic         : Magic_t;
        generation_id : GenerationId_t;
        msg_type      : MsgType_t;
    end record;
    attribute size : natural;
    attribute size of Msg_t : type is 6;

    type MsgTypeQueryResult_t is record
        valid  : std_logic;
        length : Length_t;
    end record;

    function query_msg_type(
        msg_type : MsgType_t;
    ) return MsgTypeQueryResult_t;

    function is_valid_msg(
        frame : Frame_t;
    ) return boolean;

    function get_msg(
        frame : Frame_t;
    ) return Msg_t;

    function build_msg(
        dest_mac      : MacAddress_t;
        src_mac       : MacAddress_t;
        generation_id : GenerationId_t;
        msg_type      : MsgType_t;
    ) return Frame_t;
    ----------------------------------------------------------------------------


    -------------------------------Session control------------------------------
    type SessionCtlMsg_t is record
        msg_type : MsgType_t;
    end record;
    attribute size     of SessionCtlMsg_t : type is 1;
    attribute msg_type of SessionCtlMsg_t : type is X"00";

    constant SessionCtl_Announce          : MsgType_t := X"00";
    constant SessionCtl_HandshakeRequest  : MsgType_t := X"01";
    constant SessionCtl_HandshakeResponse : MsgType_t := X"02";
    constant SessionCtl_Heartbeat         : MsgType_t := X"03";
    constant SessionCtl_Close             : MsgType_t := X"04";

    constant ANNOUNCE_INTERVAL  : natural := 1;
    constant HEARTBEAT_INTERVAL : natural := 1;
    constant TIMEOUT_INTERVAL   : natural := 3 * HEARTBEAT_INTERVAL;

    function is_valid_session_ctl_msg(
        frame : Frame_t;
    ) return boolean;

    function get_session_ctl_msg(
        frame : Frame_t;
    ) return SessionCtlMsg_t;

    function is_valid_handshake_request(
        frame : Frame_t;
    ) return boolean;

    function build_session_ctl_msg(
        dest_mac      : MacAddress_t;
        src_mac       : MacAddress_t;
        generation_id : GenerationId_t;
        msg_type      : MsgType_t;
    ) return Frame_t;
    ----------------------------------------------------------------------------


    ---------------------------------PCM control--------------------------------
    type PcmCtlMsg_t is record
        streams : Streams_t;
    end record;
    attribute size     of PcmCtlMsg_t : type is 1;
    attribute msg_type of PcmCtlMsg_t : type is X"01";

    function is_valid_pcm_ctl_msg(
        frame : Frame_t;
    ) return boolean;

    function get_pcm_ctl_msg(
        frame : Frame_t;
    ) return PcmCtlMsg_t;
    ----------------------------------------------------------------------------


    ----------------------------------PCM data----------------------------------
    -- Note:
    --
    -- When requesting 24-bit samples, ALSA left pads so that samples can be
    -- stored in a uint32_t.  To make the driver copy logic more performant, we
    -- simply pass along this data format into our PCM data messages.
    --
    -- The FPGA is responsible for converting from the unpacked representation
    -- to the packed representation.
    --
    constant UNPACKED_SAMPLE_SIZE : natural := 4;
    subtype UnpackedSample_t is std_logic_vector(
        0 to (UNPACKED_SAMPLE_SIZE * BITS_PER_BYTE) - 1
    );
    constant UnpackedSample_t_INIT : UnpackedSample_t := (others => '0');

    type UnpackedChannelPcmData_t is array (
        0 to PERIOD_SIZE - 1
    ) of UnpackedSample_t;
    constant UnpackedChannelPcmData_t_INIT : UnpackedChannelPcmData_t
        := (others => UnpackedSample_t_INIT);

    type UnpackedPeriod_t is array (
        0 to NUM_CHANNELS - 1
    ) of UnpackedChannelPcmData_t;
    constant UnpackedPeriod_t_INIT : UnpackedPeriod_t
        := (others => UnpackedChannelPcmData_t_INIT);

    type PcmDataMsg_t is record
        seqnum : unsigned(0 to (4 * BITS_PER_BYTE) - 1);
        period : UnpackedPeriod_t;
    end record;
    attribute size     of PcmDataMsg_t : type is
        4 + (2 * PERIOD_SIZE * UNPACKED_SAMPLE_SIZE);
    attribute msg_type of PcmDataMsg_t : type is X"02";

    function is_valid_pcm_data_msg(
        frame : Frame_t;
    ) return boolean;

    function get_pcm_data_msg(
        frame : Frame_t;
    ) return PcmDataMsg_t;

    function get_period(
        unpacked_period : UnpackedPeriod_t;
    ) return Period_t;

    function build_pcm_data_msg(
        dest_mac      : MacAddress_t;
        src_mac       : MacAddress_t;
        generation_id : GenerationId_t;
        seqnum        : unsigned(0 to (4 * BITS_PER_BYTE) - 1);
        period        : Period_t;
    ) return Frame_t;
    ----------------------------------------------------------------------------

end package protocol;

package body protocol is

    -----------------------------------Header-----------------------------------
    function query_msg_type(
        msg_type : MsgType_t;
    ) return MsgTypeQueryResult_t is
    begin
        case msg_type is
        when SessionCtlMsg_t'msg_type =>
            return (
                valid => '1',
                length => to_unsigned(Msg_t'size + SessionCtlMsg_t'size, 16)
            );
        when PcmCtlMsg_t'msg_type =>
            return (
                valid => '1',
                length => to_unsigned(Msg_t'size + PcmCtlMsg_t'size, 16)
            );
        when PcmDataMsg_t'msg_type =>
            return (
                valid => '1',
                length => to_unsigned(Msg_t'size + PcmDataMsg_t'size, 16)
            );
        when others =>
            return (
                valid => '0',
                length => to_unsigned(0, 16)
            );
        end case;
    end function;

    function is_valid_msg(
        frame : Frame_t;
    ) return boolean is
        variable msg    : Msg_t;
        variable result : MsgTypeQueryResult_t;
    begin
        if frame.length < Msg_t'size then
            return false;
        end if;

        msg := get_msg(frame);
        if msg.magic /= CCO_MAGIC then
            return false;
        end if;

        result := query_msg_type(msg.msg_type);
        if result.valid = '0' or frame.length /= result.length then
            return false;
        end if;

        return true;
    end function;

    function get_msg(
        frame : Frame_t;
    ) return Msg_t is
    begin
        return (
            magic => frame.payload(
                0 to (4 * BITS_PER_BYTE) - 1
            ),
            generation_id => unsigned(frame.payload(
                (4 * BITS_PER_BYTE) to (5 * BITS_PER_BYTE) - 1
            )),
            msg_type => frame.payload(
                (5 * BITS_PER_BYTE) to (6 * BITS_PER_BYTE) - 1
            )
        );
    end function;

    function build_msg(
        dest_mac      : MacAddress_t;
        src_mac       : MacAddress_t;
        generation_id : GenerationId_t;
        msg_type      : MsgType_t;
    ) return Frame_t is
        variable frame  : Frame_t := Frame_t_INIT;
        variable result : MsgTypeQueryResult_t;
    begin
        frame.dest_mac := dest_mac;
        frame.src_mac  := src_mac;

        result := query_msg_type(msg_type);
        if result.valid = '0' then
            return frame;
        end if;

        frame.dest_mac := dest_mac;
        frame.src_mac := src_mac;
        frame.length := result.length;
        frame.payload := (others => '0');
        frame.payload(
            0 to (4 * BITS_PER_BYTE) - 1
        ) := CCO_MAGIC;
        frame.payload(
            (4 * BITS_PER_BYTE) to (5 * BITS_PER_BYTE) - 1
        ) := std_logic_vector(generation_id);
        frame.payload(
            (5 * BITS_PER_BYTE) to (6 * BITS_PER_BYTE) - 1
        ) := msg_type;

        return frame;
    end function;
    ----------------------------------------------------------------------------


    -------------------------------Session control------------------------------
    function is_valid_session_ctl_msg(
        frame : Frame_t;
    ) return boolean is
        variable msg : Msg_t;
    begin
        -- Validate Msg_t
        if not is_valid_msg(frame) then
            return false;
        end if;

        -- Validate SessionCtlMsg_t
        msg := get_msg(frame);
        if msg.msg_type /= SessionCtlMsg_t'msg_type or
           frame.length /= Msg_t'size + SessionCtlMsg_t'size
        then
            return false;
        end if;

        return true;
    end function;

    function get_session_ctl_msg(
        frame : Frame_t;
    ) return SessionCtlMsg_t is
    begin
        return (
            msg_type => frame.payload(
                (6 * BITS_PER_BYTE) to (7 * BITS_PER_BYTE) - 1
            )
        );
    end function;

    function is_valid_handshake_request(
        frame : Frame_t;
    ) return boolean is
        variable msg : SessionCtlMsg_t;
    begin
        -- Validate SessionCtlMsg_t
        if not is_valid_session_ctl_msg(frame) then
            return false;
        end if;

        -- Validate session control msg_type
        msg := get_session_ctl_msg(frame);
        if msg.msg_type /= SessionCtl_HandshakeRequest then
            return false;
        end if;

        return true;
    end function;

    function build_session_ctl_msg(
        dest_mac      : MacAddress_t;
        src_mac       : MacAddress_t;
        generation_id : GenerationId_t;
        msg_type      : MsgType_t;
    ) return Frame_t is
        variable frame : Frame_t := Frame_t_INIT;
    begin
        frame := build_msg(
            dest_mac      => dest_mac,
            src_mac       => src_mac,
            generation_id => generation_id,
            msg_type      => SessionCtlMsg_t'msg_type
        );

        frame.payload(
            (6 * BITS_PER_BYTE) to (7 * BITS_PER_BYTE) - 1
        ) := msg_type;

        return frame;
    end function;
    ----------------------------------------------------------------------------


    ---------------------------------PCM control--------------------------------
    function is_valid_pcm_ctl_msg(
        frame : Frame_t;
    ) return boolean is
        variable msg : Msg_t;
    begin
        -- Validate Msg_t
        if not is_valid_msg(frame) then
            return false;
        end if;

        -- Validate PcmCtlMsg_t
        msg := get_msg(frame);
        if msg.msg_type /= PcmCtlMsg_t'msg_type or
           frame.length /= Msg_t'size + PcmCtlMsg_t'size
        then
            return false;
        end if;

        return true;
    end function;

    function get_pcm_ctl_msg(
        frame : Frame_t;
    ) return PcmCtlMsg_t is
    begin
        return (
            streams => (
                playback => (
                    active => frame.payload((6 * BITS_PER_BYTE) + 7)
                ),
                capture => (
                    active => frame.payload((6 * BITS_PER_BYTE) + 6)
                )
            )
        );
    end function;
    ----------------------------------------------------------------------------


    ----------------------------------PCM data----------------------------------
    function is_valid_pcm_data_msg(
        frame : Frame_t;
    ) return boolean is
        variable msg : Msg_t;
    begin
        -- Validate Msg_t
        if not is_valid_msg(frame) then
            return false;
        end if;

        -- Validate PcmDataMsg_t
        msg := get_msg(frame);
        if msg.msg_type /= PcmDataMsg_t'msg_type or
           frame.length /= Msg_t'size + PcmDataMsg_t'size
        then
            return false;
        end if;

        return true;
    end function;

    function get_pcm_data_msg(
        frame : Frame_t;
    ) return PcmDataMsg_t is
        variable offset : natural          := 0;
        variable period : UnpackedPeriod_t := UnpackedPeriod_t_INIT;
    begin
        for channel in 0 to NUM_CHANNELS - 1 loop
            for sample in 0 to PERIOD_SIZE - 1 loop
                offset := (10 * BITS_PER_BYTE) +
                          ((PERIOD_SIZE * channel) + sample) *
                          (UNPACKED_SAMPLE_SIZE * BITS_PER_BYTE);

                period(channel)(sample) := frame.payload(
                    offset to
                    offset + (UNPACKED_SAMPLE_SIZE * BITS_PER_BYTE) - 1
                );
            end loop;
        end loop;

        return (
            seqnum => unsigned(frame.payload(
                (6 * BITS_PER_BYTE) to (10 * BITS_PER_BYTE) - 1
            )),
            period => period
        );
    end function;

    function get_period(
        unpacked_period : UnpackedPeriod_t;
    ) return Period_t is
        variable period : Period_t := Period_t_INIT;
    begin
        for channel in 0 to NUM_CHANNELS - 1 loop
            for sample in 0 to PERIOD_SIZE - 1 loop
                period(channel)(sample) := unpacked_period(channel)(sample)(
                    8 to 31
                );
            end loop;
        end loop;

        return period;
    end function;

    function build_pcm_data_msg(
        dest_mac      : MacAddress_t;
        src_mac       : MacAddress_t;
        generation_id : GenerationId_t;
        seqnum        : unsigned(0 to (4 * BITS_PER_BYTE) - 1);
        period        : Period_t;
    ) return Frame_t is
        variable frame  : Frame_t := Frame_t_INIT;
        variable offset : natural := 0;
    begin
        frame := build_msg(
            dest_mac      => dest_mac,
            src_mac       => src_mac,
            generation_id => generation_id,
            msg_type      => PcmDataMsg_t'msg_type
        );

        frame.payload(
            (6 * BITS_PER_BYTE) to (10 * BITS_PER_BYTE) - 1
        ) := std_logic_vector(seqnum);

        for channel in 0 to NUM_CHANNELS - 1 loop
            for sample in 0 to PERIOD_SIZE - 1 loop
                offset := (10 * BITS_PER_BYTE) +
                          (PERIOD_SIZE * UNPACKED_SAMPLE_SIZE *
                           BITS_PER_BYTE * channel ) +
                          (UNPACKED_SAMPLE_SIZE * BITS_PER_BYTE * sample) +
                          (BITS_PER_BYTE);

                frame.payload(offset to offset + 23) := period(channel)(sample);
            end loop;
        end loop;

        return frame;
    end function;
    ----------------------------------------------------------------------------

end package body protocol;
