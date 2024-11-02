library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.ethernet.all;

package protocol is

    -- Message header
    subtype Magic_t is std_logic_vector(0 to (4 * BITS_PER_BYTE) - 1);
    constant CCO_MAGIC : Magic_t := X"83F8DDEF";
    subtype MsgType_t is std_logic_vector(0 to BITS_PER_BYTE - 1);
    type Msg_t is record
        magic    : Magic_t;
        msg_type : MsgType_t;
    end record;
    attribute size : natural;
    attribute size  of Msg_t : type is 5;

    attribute msg_type : MsgType_t;
                                      
    -- Card sends this to announce its presence, prompts the driver
    -- to send a handshake request
    type AnnounceMsg_t is record
    end record;
    attribute size     of AnnounceMsg_t : type is 0;
    attribute msg_type of AnnounceMsg_t : type is X"00";
               
    -- Driver sends this to initiate handshake
    type HandshakeRequestMsg_t is record
        session_id : unsigned(0 to 7);
    end record;
    attribute size     of HandshakeRequestMsg_t : type is 1;
    attribute msg_type of HandshakeRequestMsg_t : type is X"01";

    type HandshakeResponseMsg_t is record
        session_id : unsigned(0 to 7);
    end record;
    attribute size     of HandshakeResponseMsg_t : type is 1;
    attribute msg_type of HandshakeResponseMsg_t : type is X"02";

    function is_valid_msg(
        frame : Frame_t;
    ) return boolean;

    function get_msg(
        frame : Frame_t;
    ) return Msg_t;

    function is_valid_handshake_request(
        frame : Frame_t;
    ) return boolean;

    function get_handshake_request(
        frame : Frame_t;
    ) return HandshakeRequestMsg_t;

end package protocol;

package body protocol is

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
        variable result : Msg_t;
    begin
        result := (
            magic => frame.payload(
                0 to (4 * BITS_PER_BYTE) - 1
            ),
            msg_type => frame.payload(
                (4 * BITS_PER_BYTE) to (5 * BITS_PER_BYTE) - 1
            )
        );
        return result;
    end function;

    function is_valid_handshake_request(
        frame : Frame_t;
    ) return boolean is
        variable msg : Msg_t;
    begin
        if not is_valid_msg(frame) then
            return false;
        end if;

        msg := get_msg(frame);
        if msg.msg_type /= HandshakeRequestMsg_t'msg_type then
            return false;
        end if;

        if frame.length /= Msg_t'size + HandshakeRequestMsg_t'size then
            return false;
        end if;

        return true;
    end function;

    function get_handshake_request(
        frame : Frame_t;
    ) return HandshakeRequestMsg_t is
        variable result : HandshakeRequestMsg_t;
    begin
        result := (
            session_id => unsigned(frame.payload(
                (5 * BITS_PER_BYTE) to (6 * BITS_PER_BYTE) - 1
            ))
        );
        return result;
    end function;

end package body protocol;
