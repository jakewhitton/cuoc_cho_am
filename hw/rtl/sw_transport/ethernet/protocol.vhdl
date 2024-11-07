library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.ethernet.all;

package protocol is

    subtype MsgType_t is std_logic_vector(0 to BITS_PER_BYTE - 1);
    attribute size     : natural;
    attribute msg_type : MsgType_t;

    -----------------------------------Header-----------------------------------
    subtype Magic_t is std_logic_vector(0 to (4 * BITS_PER_BYTE) - 1);
    constant CCO_MAGIC : Magic_t := X"83F8DDEF";
    type Msg_t is record
        magic    : Magic_t;
        msg_type : MsgType_t;
    end record;
    attribute size of Msg_t : type is 5;

    function is_valid_msg(
        frame : Frame_t;
    ) return boolean;

    function get_msg(
        frame : Frame_t;
    ) return Msg_t;
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

    function is_valid_session_ctl_msg(
        frame : Frame_t;
    ) return boolean;

    function get_session_ctl_msg(
        frame : Frame_t;
    ) return SessionCtlMsg_t;

    function is_valid_handshake_request(
        frame : Frame_t;
    ) return boolean;
    ----------------------------------------------------------------------------

end package protocol;

package body protocol is

    -----------------------------------Header-----------------------------------
    function is_valid_msg(
        frame : Frame_t;
    ) return boolean is
        variable msg : Msg_t;
    begin
        if frame.length < Msg_t'size then
            return false;
        end if;

        msg := get_msg(frame);
        if msg.magic /= CCO_MAGIC then
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
            msg_type => frame.payload(
                (4 * BITS_PER_BYTE) to (5 * BITS_PER_BYTE) - 1
            )
        );
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
                (5 * BITS_PER_BYTE) to (6 * BITS_PER_BYTE) - 1
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
    ----------------------------------------------------------------------------

end package body protocol;
