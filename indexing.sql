-- Create these indexes if they don't exist
CREATE INDEX idx_entmod_risk_lookup ON entmod(
    tinsid, 
    status, 
    decode(segind,'A',1,'I',1,'C',1,0),
    tinsid
);

CREATE INDEX idx_trantrail_risk_lookup ON trantrail(
    tinsid, 
    status, 
    decode(type,'2',1,'F',1,'G',1,'I',1,0),
    e.tinsid,
    mft
);

-- For the estate_tax query
CREATE INDEX idx_ent_tinsid ON ent(tinsid);
CREATE INDEX idx_codetable ON codetable(codesid, code, dtchng);
