// Address map for LSU routing (spec §13.2)
module addr_decode (
  input  logic [31:0] addr,
  output logic        use_sbus
);
  always_comb begin
    use_sbus = 1'b0;
    if ((addr >= 32'h4000_0000) && (addr <= 32'h4FFF_FFFF))
      use_sbus = 1'b1;
    else if (addr >= 32'hF000_0000)
      use_sbus = 1'b1;
  end
endmodule
