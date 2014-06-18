#!/usr/bin/env ruby

require 'include/pdu'
require 'iconv'

puts "== test toa_int2ary"
a = PDU.toa_int2ary(0x91)
p a
i = PDU.toa_ary2int(a)
p '%02X' % i

puts "== test octets_to_bits7 and str2octet"
p PDU.bits7_to_str( PDU.octets_to_bits7('68656C6C6F') )
p PDU.fo_int2ary(4)
s = "Mony€t gant£nx"
#s = "y€tora"
puts "s.length: #{s.length}"
puts "s.unpack: #{s.unpack('U*').inspect}"
o,ol = PDU.str2octet(s)
puts "s->ol: #{ol}"
puts "s->o: #{o}"
puts PDU.bits7_to_str( PDU.octets_to_bits7(o), ol )
o = "DC6155EF677A7D".nibble_swap
puts PDU.bits7_to_str( PDU.octets_to_bits7(o) )
#p Iconv.new('iso-8859-15', 'utf-8').iconv("t£ma€n")

puts "== test PDU.read()"
pdu_string = 
#'05912618164204038177F70000805050611121828BD4235237A587E9F539881E3EA7D16137081E268741F4B0FB7C0EB3752059AD15844A5B30DC4E410D9FD3E8B01B442FCBC36B745AAE0349E1A0D86CE682D1723B05F54D0FB341F4F0398D0EBB7520291C149BCD5C305A4EA10CD3EB6810BDDC86BF41F4F0398D0EBB41F4B23CBC46A7E53A50ACD66A06B32D180E' # 137 
#'06C6038177F78050503122008280505031220082000014440000000012' # 29
#'05912618164204038177F70000805050617375826FD02A53079AD2C3F4FA1C042FB7C3EB703AEC0641ABCC7918147493C3201D480A07CD6AB51C8E0522A7D1697ADD7D0691C3F234881A3EA7D16137885E9687D7E8B49C051297D9F536885E96B7C3F3FA1A1416BFDDE576D90D3281A0502728062BB900'# 113
#'0031FF039177F70000AA03D02A13'
#'0891269846040000F1B101048144440000FF59A3990C468BC96232D80C4783C162B1D19A0E1F99C364749A3D8AC95EB0D90B471BB1D1EFF5BC5C6F87EFE5919AED12BFD56FF719347F87DD67D0F90C829FC3A018AC065A87C52E71D84DAEBBCF23'
#'06912618010000640D91265822104127F40000804072224582822D050003CC0202C27310F9EC06CDDBF530287F06D5C96134889C0EAFC36C59DA0D9AB7416DF93AEC02'
#'06912618010000440D91265892372093F90008804082219231828C050003F70201005900650073002C006800650020006B006E006500770020007000700020006E006F007400200069006E0020007400680065002000730061006D006500200074007200610063007400200077002000740061006E0069002C006800650020006800730020006200650065006E002000740061006B0069006E0067002000740068006900730020'
#'06912618010000640D91265892372093F900088040822192918238050003F702020073006900740075006100740069006F006E00200066006F00720020006800690073002000620065006E0065006600690074'
#'07911614786007F0040B911604994743F400009930139100406B05E8329BFD06'
#'0011000B916407281553F80000AA0AE8329BFD4697D9EC37'
#'0011000A81409079344400000105E8329BFD06'
#'07911614786007F011000A81409079344400F6AA0568656C6C6F'
# '059126181642040ED0CD1655FE76A7D70000708010903313826DCEB70BFE76CFCB6C50D84D0E83E86576180D1297E5E8F03CCD0691D3F437BC0E072183CE690E269381E66571791E9683A470500CC682C1602078981C06C1622D18AE2583C16EA0301D04CBE966B360D30572BE5DD2B25947A3CD66381C4C5603'
#'059126181642000ED04927F1390D5241000070807090643100A0D2701A0D8AC940D4E4B24805ADCBA0243DCC4E875920E4F2C80209C3EEF3FABD66816420EA3BFFA68741D2FA1CCD02D940D9703B8C0E839AE9372B860321A120E70DC602D97020A70D7683B940CB323DBDD681A4C523884A04ADCBA0990D974349E135186C0587BB532ED094FE86EBAA4E69F108A21241EBF2CC86CBB94049B7F9AD83C96233D80D669BE572'
# '07912658050000F0040DD04927F1390D52010000707081505103004CD3323BDC0ED359A0A09B1C0691C3F0301D247EBBEB73500D346D4E5DA069730A1297E5ECF0BA0EAAD3D7207A5D5D0FBB41CDB29B1E96A759C9E60C640235C374791A0F'
#'07917283010010F5040BC87238880900F10000993092516195800AE8329BFD4697D9EC37'
'0006030B818051075093F6805050814522828050508145728200' # 25

length_pdu = nil

puts pdu_string.length / 2
puts pdu_string
info = PDU.read(pdu_string, length_pdu)
p info


exit

puts "== test PDU.write() then assert with PDU.read()"
info = {'first_octet' => ['sms-submit', 'v-rel'], 'message_ref' => 0, 
'number' => '08157005396',  'validity_period' => 0xAA, 'message' => 'selamat malam teman saya 小坂りゆ !',
'user_header' => '000401020304',
'data_coding' => ['general', 'ucs2'] }  
p info
pdu, length_pdu = PDU.write(info)
puts "pdu: #{pdu}"
puts "length_pdu: #{length_pdu}"
p PDU.read(pdu)


