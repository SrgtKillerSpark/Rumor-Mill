# Fixture: SPA-1678/1684 reproduction — class with constant removed.
# RivalAgent used to have MAX_DISRUPT_CHARGES but it was removed.
class_name RivalAgent
extends Node

const AGENT_NAME := "Rival"
# MAX_DISRUPT_CHARGES was removed — any reference should be caught by Check 7
