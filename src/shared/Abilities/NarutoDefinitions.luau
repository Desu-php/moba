--!strict
-- Source: Naruto Legend 1.7A FIX20.3; contract libfile_de3939fe995081919fd57704506aa2b1.
-- Source verification is not Roblox runtime readiness. No distances below are studs.
local lines = {
	table.freeze({ Id = "Rasengan", Rawcode = "A014", Name = "Расенган", SourceStatus = "BaseVerified", RuntimeReady = false }),
	table.freeze({ Id = "ShadowClones", Rawcode = "A04N", Name = "Теневые клоны", SourceStatus = "BaseVerified", RuntimeReady = false }),
	table.freeze({ Id = "Gamakichi", Rawcode = "A005", Name = "Гамакичи", SourceStatus = "Planned", RuntimeReady = false }),
	table.freeze({ Id = "SageMode", Rawcode = "A09J", Name = "Режим мудреца", SourceStatus = "Planned", RuntimeReady = false }),
	table.freeze({ Id = "KCM", Rawcode = "A017", Name = "KCM", SourceStatus = "Planned", RuntimeReady = false }),
}
return table.freeze({
	SourceVersion = "1.7A FIX20.3",
	SourceSHA256 = "8c5750f178a7f1d66a4f04e8d0c585168e51f93c924149858fbb8d731193a5c8",
	Lines = table.freeze(lines),
	Hero = table.freeze({
		UnitRawcode = "Hpal", Strength = 16, StrengthGrowth = 1.4, Agility = 15, AgilityGrowth = 1.1,
		Intelligence = 14, IntelligenceGrowth = 1, BaseMana = 1300, InitialManaField = 9999,
		BaseHealth = 300, HealthPerStrength = 20, MapLevelCap = 30,
	}),
	NativeInference = table.freeze({
		RuntimeCertified = false, ManaPerIntelligence = 15, RegenPerIntelligence = 0.05,
		BaseManaRegen = 0.01, BaseSpeedWarcraft = 270,
	}),
	Rasengan = table.freeze({
		Ranks = 3, RequiredLevel = 4, RankSkip = 7, ManaCost = 100, Cooldown = 60,
		Preparation = 2, HoldDuration = 15, AttackControlDelay = 0.01, ImpactDelay = 1, Stun = 3.5,
		VariantWindow = 1, HandEffectDelay = 1.5, HelperOffsetWarcraft = 120,
		BaseDamage = 120, StrengthFactor = 1, LevelFactor = 10,
	}),
	Clones = table.freeze({
		Counts = table.freeze({ 3, 4, 5, 7 }), Cooldowns = table.freeze({ 50, 46, 42, 38 }),
		ManaCost = 200, RangeWarcraft = 2000, Lifetime = 20, SpawnInterval = 0.01,
		OutgoingMultiplier = 0.30, IncomingMultiplier = 20,
		MassCount = 30, MassManaFraction = 0.30,
		SleepDuration = 3, SleepCosmetics = 5, SleepRadiusWarcraft = 120,
		PayloadLevelFactor = 4, PayloadStrengthFactor = 0.30,
		PayloadDisplacementWarcraft = 600, PayloadDisplacementDuration = 0.5,
	}),
	-- Deliberately absent: inherited rank-1 buff speed, clone unlock levels,
	-- generic skill-point cost and native resource ordering.
	Unsupported = table.freeze({
		"OdamaAdapter", "Rasenshuriken", "SageMode", "KCM", "Gamakichi",
		"ClonePointAdvanced", "AlternateClonePayload", "NativeSleepWakePolicy",
	}),
})
