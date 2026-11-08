// Hotswap - what each perk is worth, and what V has to carry for it to matter.
//
// Written from reading every perk in the game (2.5). A value runs from 1 to 9: 9 is what a playstyle
// is built around, and 1 is barely noticeable. 0 is for perks a build gets nothing from in a fight,
// such as vehicle stunts, crafting and dual wielding, which recommended builds don't use.
//
// A gate names what V's kit needs before the perk counts. Recommended builds only buy perks worth
// something with their gate open, plus whatever those perks require. "never" is an unused perk.
//
// A perk that isn't listed, such as one a mod adds, gets a middling value and no gate.

public class HotswapPerkKnowledge {
  private let m_names: array<CName>;
  private let m_values: array<Int32>;
  private let m_gates: array<CName>;

  public static func Load() -> ref<HotswapPerkKnowledge> {
    let k = new HotswapPerkKnowledge();

    // Body: Adrenaline Rush and regeneration help anyone who gets hit
    k.Add(n"Body_Central_Milestone_1", 7, n"");
    k.Add(n"Body_Central_Perk_1_1", 3, n"");
    k.Add(n"Body_Central_Perk_1_2", 5, n"");
    k.Add(n"Body_Central_Perk_1_3", 4, n"");
    k.Add(n"Body_Central_Perk_1_4", 4, n"");
    k.Add(n"Body_Central_Milestone_3", 9, n"");
    k.Add(n"Body_Central_Perk_3_1", 5, n"");
    k.Add(n"Body_Central_Perk_3_2", 7, n"");
    k.Add(n"Body_Central_Perk_3_4", 6, n"");
    k.Add(n"Body_Master_Perk_3", 7, n"");
    // Body: shotguns and machine guns
    k.Add(n"Body_Left_Milestone_2", 6, n"heavy");
    k.Add(n"Body_Left_Perk_2_1", 5, n"heavy");
    k.Add(n"Body_Left_Perk_2_3", 4, n"heavy");
    k.Add(n"Body_Left_Perk_2_4", 6, n"heavy");
    k.Add(n"Body_Left_Milestone_3", 8, n"heavy");
    k.Add(n"Body_Left_Perk_3_1", 5, n"heavy");
    k.Add(n"Body_Left_Perk_3_2", 6, n"heavy");
    k.Add(n"Body_Left_Perk_3_3", 6, n"heavy");
    k.Add(n"Body_Left_Perk_3_4", 7, n"heavy");
    k.Add(n"Body_Inbetween_Left_3", 5, n"heavy");
    k.Add(n"Body_Master_Perk_1", 8, n"heavy");
    k.Add(n"Body_Master_Perk_2", 6, n"heavy");
    // Body: blunt weapons and Gorilla Arms
    k.Add(n"Body_Right_Milestone_1", 0, n"");
    k.Add(n"Body_Right_Milestone_2", 6, n"blunt");
    k.Add(n"Body_Right_Perk_2_1", 5, n"blunt");
    k.Add(n"Body_Right_Perk_2_2", 5, n"blunt");
    k.Add(n"Body_Right_Perk_2_3", 4, n"blunt");
    k.Add(n"Body_Right_Perk_2_4", 6, n"blunt");
    k.Add(n"Body_Right_Milestone_3", 8, n"blunt");
    k.Add(n"Body_Right_Perk_3_1", 6, n"blunt");
    k.Add(n"Body_Right_Perk_3_2", 5, n"blunt");
    k.Add(n"Body_Inbetween_Right_3", 6, n"blunt");
    k.Add(n"Body_Master_Perk_5", 8, n"blunt");

    // Reflexes: movement, which suits everyone, and shooting on the move, which suits guns
    k.Add(n"Reflexes_Left_Milestone_1", 0, n"");
    k.Add(n"Reflexes_Central_Milestone_1", 7, n"");
    k.Add(n"Reflexes_Central_Perk_1_1", 2, n"");
    k.Add(n"Reflexes_Central_Perk_1_2", 5, n"ranged");
    k.Add(n"Reflexes_Central_Perk_1_3", 1, n"");
    k.Add(n"Reflexes_Central_Perk_1_4", 6, n"ranged");
    k.Add(n"Reflexes_Central_Milestone_2", 8, n"");
    k.Add(n"Reflexes_Central_Perk_2_1", 5, n"melee");
    k.Add(n"Reflexes_Central_Perk_2_2", 6, n"");
    k.Add(n"Reflexes_Central_Perk_2_3", 4, n"");
    k.Add(n"Reflexes_Central_Perk_2_4", 6, n"ranged");
    k.Add(n"Reflexes_Central_Milestone_3", 7, n"");
    k.Add(n"Reflexes_Central_Perk_3_2", 3, n"");
    k.Add(n"Reflexes_Central_Perk_3_3", 4, n"");
    k.Add(n"Reflexes_Master_Perk_3", 6, n"");
    k.Add(n"Reflexes_Inbetween_Left_3", 5, n"kerenzikov");
    // Reflexes: assault rifles and SMGs
    k.Add(n"Reflexes_Left_Milestone_2", 6, n"automatic");
    k.Add(n"Reflexes_Left_Perk_2_2", 4, n"automatic");
    k.Add(n"Reflexes_Left_Perk_2_3", 6, n"automatic");
    k.Add(n"Reflexes_Left_Perk_2_4", 6, n"automatic");
    k.Add(n"Reflexes_Left_Milestone_3", 8, n"automatic");
    k.Add(n"Reflexes_Left_Perk_3_1", 6, n"automatic");
    k.Add(n"Reflexes_Left_Perk_3_2", 5, n"automatic");
    k.Add(n"Reflexes_Left_Perk_3_3", 7, n"automatic");
    k.Add(n"Reflexes_Left_Perk_3_4", 6, n"automatic");
    k.Add(n"Reflexes_Master_Perk_1", 8, n"automatic");
    k.Add(n"Reflexes_Master_Perk_2", 7, n"automatic");
    // Reflexes: blades and Mantis Blades
    k.Add(n"Reflexes_Right_Milestone_2", 7, n"blades");
    k.Add(n"Reflexes_Right_Perk_2_1", 7, n"blades");
    k.Add(n"Reflexes_Right_Perk_2_2", 5, n"blades");
    k.Add(n"Reflexes_Right_Perk_2_3", 6, n"blades");
    k.Add(n"Reflexes_Inbetween_Right_2", 8, n"blades");
    k.Add(n"Reflexes_Right_Milestone_3", 9, n"blades");
    k.Add(n"Reflexes_Right_Perk_3_1", 7, n"blades");
    k.Add(n"Reflexes_Right_Perk_3_3", 6, n"blades");
    k.Add(n"Reflexes_Right_Perk_3_4", 5, n"blades");
    k.Add(n"Reflexes_Master_Perk_5", 9, n"blades");

    // Technical Ability: what every piece of cyberware gains
    k.Add(n"Tech_Central_Milestone_2", 8, n"");
    k.Add(n"Tech_Central_Perk_2_1", 7, n"");
    k.Add(n"Tech_Central_Perk_2_2", 8, n"");
    k.Add(n"Tech_Central_Perk_2_3", 0, n"");
    k.Add(n"Tech_Central_Perk_2_4", 6, n"");
    k.Add(n"Tech_Inbetween_Right_2", 0, n"");
    k.Add(n"Tech_Central_Milestone_3", 9, n"");
    k.Add(n"Tech_Central_Perk_3_1", 6, n"");
    k.Add(n"Tech_Central_Perk_3_2", 7, n"");
    k.Add(n"Tech_Central_Perk_3_3", 6, n"adaptive");
    k.Add(n"Tech_Central_Perk_3_4", 6, n"");
    k.Add(n"Tech_Master_Perk_3", 8, n"");
    // Technical Ability: health items and grenades
    k.Add(n"Tech_Left_Milestone_1", 7, n"");
    k.Add(n"Tech_Left_Perk_1_1", 5, n"");
    k.Add(n"Tech_Left_Perk_1_2", 5, n"");
    k.Add(n"Tech_Left_Milestone_2", 7, n"");
    k.Add(n"Tech_Left_Perk_2_1", 4, n"");
    k.Add(n"Tech_Left_Perk_2_2", 6, n"");
    k.Add(n"Tech_Left_Perk_2_3", 5, n"");
    k.Add(n"Tech_Left_Perk_2_4", 3, n"");
    k.Add(n"Tech_Left_Milestone_3", 5, n"");
    k.Add(n"Tech_Left_Perk_3_01", 3, n"");
    k.Add(n"Tech_Left_Perk_3_2", 3, n"");
    k.Add(n"Tech_Left_Perk_3_3", 1, n"");
    k.Add(n"Tech_Left_Perk_3_4", 4, n"");
    k.Add(n"Tech_Inbetween_Left_3", 7, n"launcher");
    k.Add(n"Tech_Master_Perk_2", 6, n"");
    // Technical Ability: charged Tech weapons
    k.Add(n"Tech_Right_Milestone_1", 0, n"");
    k.Add(n"Tech_Right_Milestone_3", 9, n"charged");
    k.Add(n"Tech_Right_Perk_3_1", 6, n"charged");
    k.Add(n"Tech_Right_Perk_3_2", 6, n"charged");
    k.Add(n"Tech_Right_Perk_3_3", 8, n"charged");
    k.Add(n"Tech_Right_Perk_3_4", 7, n"charged");
    k.Add(n"Tech_Master_Perk_5", 9, n"charged");

    // Intelligence: quickhack queue
    k.Add(n"Intelligence_Left_Milestone_1", 5, n"deck");
    k.Add(n"Intelligence_Left_Perk_1_1", 3, n"deck");
    k.Add(n"Intelligence_Left_Perk_1_2", 3, n"deck");
    k.Add(n"Intelligence_Left_Milestone_2", 9, n"deck");
    k.Add(n"Intelligence_Left_Perk_2_1", 4, n"deck");
    k.Add(n"Intelligence_Left_Perk_2_2", 6, n"deck");
    k.Add(n"Intelligence_Left_Perk_2_3", 3, n"deck");
    k.Add(n"Intelligence_Left_Perk_2_4", 7, n"deck");
    k.Add(n"Intelligence_Left_Milestone_3", 9, n"deck");
    k.Add(n"Intelligence_Left_Perk_3_1", 7, n"deck");
    k.Add(n"Intelligence_Left_Perk_3_2", 6, n"deck");
    k.Add(n"Intelligence_Left_Perk_3_4", 7, n"wires");
    k.Add(n"Intelligence_Inbetween_Left_3", 6, n"deck");
    k.Add(n"Intelligence_Master_Perk_1", 9, n"deck");
    // Intelligence: RAM and Overclock
    k.Add(n"Intelligence_Central_Milestone_1", 8, n"deck");
    k.Add(n"Intelligence_Central_Perk_1_1", 5, n"deck");
    k.Add(n"Intelligence_Central_Perk_1_2", 6, n"deck");
    k.Add(n"Intelligence_Central_Perk_1_3", 4, n"deck");
    k.Add(n"Intelligence_Central_Milestone_2", 8, n"deck");
    k.Add(n"Intelligence_Central_Perk_2_1", 7, n"deck");
    k.Add(n"Intelligence_Central_Perk_2_2", 7, n"deck");
    k.Add(n"Intelligence_Central_Perk_2_3", 8, n"deck");
    k.Add(n"Intelligence_Central_Perk_2_4", 4, n"deck");
    k.Add(n"Intelligence_Inbetween_Left_2", 7, n"wires");
    k.Add(n"Intelligence_Central_Milestone_3", 9, n"deck");
    k.Add(n"Intelligence_Central_Perk_3_1", 6, n"deck");
    k.Add(n"Intelligence_Central_Perk_3_2", 7, n"deck");
    k.Add(n"Intelligence_Central_Perk_3_3", 7, n"deck");
    k.Add(n"Intelligence_Master_Perk_3", 8, n"deck");
    k.Add(n"Intelligence_Master_Perk_4", 7, n"smart");
    // Intelligence: Smart weapons
    k.Add(n"Intelligence_Right_Milestone_1", 0, n"");
    k.Add(n"Intelligence_Right_Milestone_2", 6, n"smart");
    k.Add(n"Intelligence_Right_Perk_2_1", 6, n"smart");
    k.Add(n"Intelligence_Right_Perk_2_2", 6, n"smart");
    k.Add(n"Intelligence_Inbetween_Right_2", 6, n"smart");
    k.Add(n"Intelligence_Right_Milestone_3", 8, n"smart");
    k.Add(n"Intelligence_Right_Perk_3_1", 8, n"smart");
    k.Add(n"Intelligence_Right_Perk_3_2", 7, n"smart");

    // Cool: pistols, revolvers and rifles aimed for the head
    k.Add(n"Cool_Left_Milestone_1", 0, n"");
    k.Add(n"Cool_Left_Milestone_2", 7, n"precise");
    k.Add(n"Cool_Left_Perk_2_1", 6, n"precise");
    k.Add(n"Cool_Left_Perk_2_2", 5, n"precise");
    k.Add(n"Cool_Left_Perk_2_3", 1, n"precise");
    k.Add(n"Cool_Left_Perk_2_4", 5, n"precise");
    k.Add(n"Cool_Inbetween_Left_2", 6, n"precise");
    k.Add(n"Cool_Left_Milestone_3", 9, n"precise");
    k.Add(n"Cool_Left_Perk_3_1", 5, n"precise");
    k.Add(n"Cool_Left_Perk_3_2", 5, n"precise");
    k.Add(n"Cool_Left_Perk_3_3", 7, n"precise");
    k.Add(n"Cool_Left_Perk_3_4", 6, n"precise");
    k.Add(n"Cool_Master_Perk_1", 9, n"precise");
    k.Add(n"Cool_Master_Perk_2", 6, n"precise");
    // Cool: moving unseen
    k.Add(n"Cool_Central_Milestone_1", 6, n"quiet");
    k.Add(n"Cool_Central_Perk_1_1", 4, n"quiet");
    k.Add(n"Cool_Central_Perk_1_2", 3, n"quiet");
    k.Add(n"Cool_Central_Perk_1_4", 5, n"quiet");
    k.Add(n"Cool_Central_Milestone_3", 6, n"quiet");
    k.Add(n"Cool_Central_Perk_3_1", 5, n"quiet");
    k.Add(n"Cool_Central_Perk_3_2", 7, n"quiet");
    k.Add(n"Cool_Central_Perk_3_4", 5, n"quiet");
    k.Add(n"Cool_Inbetween_Left_3", 6, n"camo");
    // Cool: dual wielding, which recommended builds leave out
    k.Add(n"Cool_Central_Milestone_2", 0, n"");
    k.Add(n"Cool_Central_Perk_2_1", 0, n"");
    k.Add(n"Cool_Central_Perk_2_2", 0, n"");
    k.Add(n"Cool_Central_Perk_2_3", 0, n"");
    k.Add(n"Cool_Central_Perk_2_4", 0, n"");
    // Cool: silent kills, then throwing knives and axes
    k.Add(n"Cool_Right_Milestone_1", 8, n"silent");
    k.Add(n"Cool_Right_Perk_1_1", 6, n"silent");
    k.Add(n"Cool_Right_Perk_1_2", 5, n"silent");
    k.Add(n"Cool_Right_Milestone_2", 7, n"thrown");
    k.Add(n"Cool_Right_Perk_2_1", 3, n"thrown");
    k.Add(n"Cool_Right_Perk_2_2", 5, n"thrown");
    k.Add(n"Cool_Right_Perk_2_3", 6, n"thrown");
    k.Add(n"Cool_Right_Perk_2_4", 5, n"thrown");
    k.Add(n"Cool_Right_Milestone_3", 9, n"thrown");
    k.Add(n"Cool_Right_Perk_3_1", 5, n"thrown");
    k.Add(n"Cool_Right_Perk_3_2", 8, n"thrown");
    k.Add(n"Cool_Right_Perk_3_3", 0, n"never");
    k.Add(n"Cool_Right_Perk_3_4", 7, n"thrown");
    k.Add(n"Cool_Inbetween_Right_3", 6, n"thrown");
    k.Add(n"Cool_Master_Perk_4", 8, n"thrown");

    // Relic: each arm's ability only helps the arms V wears
    k.Add(n"Espionage_Left_Milestone_Perk", 7, n"camo");
    k.Add(n"Espionage_Left_Perk_1_2", 6, n"quiet");
    k.Add(n"Espionage_Central_Milestone_1", 8, n"anyarm");
    k.Add(n"Espionage_Central_Perk_1_1", 7, n"launcher");
    k.Add(n"Espionage_Central_Perk_1_2", 7, n"gorilla");
    k.Add(n"Espionage_Central_Perk_1_3", 7, n"wires");
    k.Add(n"Espionage_Central_Perk_1_4", 7, n"mantis");
    k.Add(n"Espionage_Right_Milestone_1", 7, n"");
    k.Add(n"Espionage_Right_Perk_1_1", 6, n"");
    return k;
  }

  private func Add(name: CName, value: Int32, gate: CName) -> Void {
    ArrayPush(this.m_names, name);
    ArrayPush(this.m_values, value);
    ArrayPush(this.m_gates, gate);
  }

  public func ValueOf(name: CName) -> Int32 {
    let index = ArrayFindFirst(this.m_names, name);
    return index >= 0 ? this.m_values[index] : 3;
  }

  public func GateOf(name: CName) -> CName {
    let index = ArrayFindFirst(this.m_names, name);
    return index >= 0 ? this.m_gates[index] : n"";
  }
}
